#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Сопоставление китайских названий МИИТ с рыночными (RU/KZ).

Читает data/miit/*.jsonl, группирует записи по марке и модели, проверяет
кандидатов из data/alias_candidates.csv и выдаёт:

  data/alias_verified.csv   - только те соответствия, что НАЙДЕНЫ в данных
  data/miit_models_top.md   - топ моделей по каждой марке (для ручной сверки)

Ничего не выдумывает: если написание не встретилось - оно попадает в отчёт
как "не найдено", а не в таблицу соответствий.
"""

from __future__ import print_function

import collections
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')
MIIT = os.path.join(DATA, 'miit')
sys.path.insert(0, HERE)

from miit_import import (  # noqa: E402
    BRAND_TABLE, apply_sub_brand, brand_in_text, cn_from_producer,
    split_brand_model,
)


def iter_records(registry):
    path = os.path.join(MIIT, registry + '.jsonl')
    if not os.path.exists(path):
        return
    with io.open(path, 'r', encoding='utf-8', errors='replace') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            yield rec


def brand_model(rec, registry):
    """-> (наша марка, китайская марка, китайская модель, обычное имя)."""
    usual = (rec.get('usualName') or '').strip()
    producer = (rec.get('oversrasName') or rec.get('enterpriseName') or '').strip()
    hint = (rec.get('vehicleBrand') or '').strip().rstrip('牌')
    cn_brand, model, own = split_brand_model(usual, hint)
    if not own:
        bcn, bown = brand_in_text(usual)
        if bown:
            own, cn_brand = bown, (cn_brand or bcn)
        else:
            pcn, pown = brand_in_text(producer)
            if pown:
                cn_brand, own = pcn, pown
            else:
                cn_brand = cn_brand or pcn or cn_from_producer(producer)
        # Марка не была префиксом названия - имя модели берём целиком
        # (瑞虎8 остаётся 瑞虎8, а не «8»).
        model = usual
        if bown and model.startswith(bcn):
            model = model[len(bcn):].strip()
    if hint and not own:
        hcn, hown = brand_in_text(hint)
        if hown:
            own, cn_brand = hown, hcn
    return (own, cn_brand, model, usual)


def collect(registries=('queryList', 'queryNewList')):
    """-> (models: {brand: Counter(model)}, samples: {(brand,model): usual})"""
    models = collections.defaultdict(collections.Counter)
    samples = {}
    totals = collections.Counter()
    for reg in registries:
        for rec in iter_records(reg):
            own, cn, model, usual = brand_model(rec, reg)
            if not own:
                own = cn or '(без марки)'
            model = (model or '').strip()
            if not model:
                model = (rec.get('vehicleModel') or '').strip()
            if not model:
                continue
            own = apply_sub_brand(own, model)
            models[own][model] += 1
            totals[own] += 1
            samples.setdefault((own, model), usual)
    return models, samples, totals


def load_candidates():
    path = os.path.join(DATA, 'alias_candidates.csv')
    out = []
    with io.open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(';')
            if len(parts) < 3:
                continue
            out.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return out


def _find(brand, models, pat):
    """Ищем написание: сначала у ожидаемой марки, потом у всех остальных.

    Нужно потому, что часть марок лежит внутри чужой (Tank -> Great Wall,
    Omoda -> Chery): марку берём из данных, а не из предположения.
    """
    hits = []
    pl = pat.lower()
    for b, table in models.items():
        for model, cnt in table.items():
            if pl in model.lower():
                hits.append((b, model, cnt))
    if not hits:
        return None
    hits.sort(key=lambda x: (x[0] != brand, -x[2], len(x[1])))
    return hits[0]


def verify(models, samples, candidates):
    """-> (найденные, ненайденные). Соответствие = есть хотя бы 1 запись."""
    found, missing = [], []
    for brand, market, patterns in candidates:
        pats = [x for x in patterns.split('|') if x]
        got = []
        for pat in pats:
            hit = _find(brand, models, pat)
            if hit:
                b, model, cnt = hit
                got.append((b, model, cnt))
        if got:
            got.sort(key=lambda x: -x[2])
            for b, model, cnt in got:
                found.append((market, brand, b, model, cnt,
                              samples.get((b, model), '')))
        else:
            missing.append((brand, market, patterns))
    return found, missing


def write_verified(found):
    path = os.path.join(DATA, 'alias_verified.csv')
    buf = io.StringIO()
    buf.write('market_brand;market_model;data_brand;model_cn;records;sample_usual_name\n')
    for market, brand, b, cn, cnt, sample in found:
        buf.write('%s;%s;%s;%s;%d;%s\n' % (brand, market, b, cn, cnt,
                                           (sample or '').replace(';', ',')))
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(buf.getvalue())
    return path


def write_models_md(models, totals, target_brands):
    path = os.path.join(DATA, 'miit_models_top.md')
    buf = io.StringIO()
    buf.write('# Топ моделей по маркам (по данным МИИТ КНР)\n\n')
    buf.write('Сгенерировано tools/miit_aliases.py. Китайские написания - как в реестре.\n\n')
    for brand in target_brands:
        cnt = totals.get(brand, 0)
        if not cnt:
            continue
        buf.write('\n## %s - %d записей\n\n' % (brand, cnt))
        for model, n in models[brand].most_common(40):
            buf.write('* %s - %d\n' % (model, n))
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(buf.getvalue())
    return path


def main():
    models, samples, totals = collect()
    print('марок: %d | записей с моделью: %d' % (len(models), sum(totals.values())))
    cands = load_candidates()
    found, missing = verify(models, samples, cands)
    print('кандидатов: %d | подтверждено данными: %d | не найдено: %d'
          % (len(cands), len(found), len(missing)))
    p1 = write_verified(found)
    print('->', p1)
    interesting = sorted(totals, key=lambda b: -totals[b])
    p2 = write_models_md(models, totals, interesting)
    print('->', p2)
    print('\nНЕ НАЙДЕНО (проверить написание):')
    for brand, market, pats in missing:
        print('  %-14s %-16s %s' % (brand, market, pats))


if __name__ == '__main__':
    main()
