#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Сборка каталога FuelMaster: базовый каталог + данные МИИТ.

Ничего не удаляет молча: по умолчанию только ДОБАВЛЯЕТ строки, которых нет
в базовом каталоге, и пишет отчёт. Существующие строки не трогает.

Запуск:
    python tools/build_catalog.py --dry-run      # только отчёт, файл не меняется
    python tools/build_catalog.py                # записать assets/cars.csv (с бэкапом)
    python tools/build_catalog.py --replace-cn    # + убрать шаблонные строки по CN-маркам
    python tools/build_catalog.py --include-foreign
"""

import argparse
import collections
import csv
import io
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')
sys.path.insert(0, HERE)

from miit_import import _BRAND_MAP  # noqa: E402  (список китайских марок)

CATALOG = os.path.join(ROOT, 'assets', 'cars.csv')
MIIT_ROWS = os.path.join(DATA, 'catalog_miit.csv')
# Чистый базовый каталог (без строк МИИТ). Сборка ВСЕГДА идёт от него, иначе
# повторный запуск принял бы за основу уже слитый файл и результат зависел бы
# от числа запусков.
BASE_SNAPSHOT = os.path.join(DATA, 'cars_base.csv')

BASE_COLUMNS = [
    'brand', 'model', 'modification', 'cylinders', 'powerHp', 'engineVolume',
    'transmissionType', 'transmissionSpeeds', 'baseCityNorm',
    'baseHighwayNorm', 'fuelType', 'vehicleType',
]

PROVENANCE = [
    'baseCombinedNorm', 'testCycle', 'normSource', 'sourceRef', 'publicTime',
    'energyType', 'driveType', 'aliasCn', 'brandCn', 'region',
    'phaseLow', 'phaseMid', 'phaseHigh', 'phaseExtra', 'electricKwh',
    'co2', 'drivingRange', 'mass',
]

# Марки, для которых основной рынок - не КНР: их нормы из китайского реестра
# в каталог не подмешиваем (иная комплектация), только по флагу.
FOREIGN_BRANDS = set([
    'Audi', 'BMW', 'Mercedes-Benz', 'Volkswagen', 'Toyota', 'Honda', 'Nissan',
    'Ford', 'Chevrolet', 'Buick', 'Hyundai', 'KIA', 'Skoda', 'Volvo',
    'Porsche', 'Lexus', 'Jaguar', 'Land Rover', 'Jaguar Land Rover', 'Mazda',
    'Mitsubishi', 'Suzuki', 'Peugeot', 'Citroen', 'Fiat', 'Jeep', 'Dodge',
    'Cadillac', 'Lincoln', 'Tesla', 'Subaru', 'Infiniti', 'Renault', 'Opel',
    'Iveco', 'Scania', 'MAN', 'MINI', 'Genesis', 'Acura', 'Saab',
    'Lamborghini', 'Ferrari', 'Maserati', 'Bentley', 'Rolls-Royce',
    'Aston Martin', 'McLaren', 'Bugatti', 'Smart', 'Lotus', 'Soueast',
])

CN_BRANDS = set(v for v in _BRAND_MAP.values() if v not in FOREIGN_BRANDS)


def read_csv(path):
    if not os.path.exists(path):
        return [], []
    with io.open(path, 'r', encoding='utf-8-sig', errors='replace', newline='') as fh:
        rows = list(csv.reader(fh))
    if not rows:
        return [], []
    return rows[0], [r for r in rows[1:] if r and any(x.strip() for x in r)]


def norm_brand(s):
    return (s or '').strip().lower()


def key3(brand, model, mod):
    return (norm_brand(brand), (model or '').strip().lower(),
            (mod or '').strip().lower())


def load_aliases():
    """data/alias_verified.csv -> {(марка МИИТ, модель CN): (рынок.марка, рынок.модель)}.

    Таблица собрана tools/miit_aliases.py: в неё попадают только те написания,
    которые реально встречаются в реестре.
    """
    path = os.path.join(DATA, 'alias_verified.csv')
    out = {}
    if not os.path.exists(path):
        return out
    with io.open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('market_brand;'):
                continue
            parts = line.split(';')
            if len(parts) < 4:
                continue
            market_brand, market_model, data_brand, model_cn = parts[0], parts[1], parts[2], parts[3]
            out[(data_brand.strip(), model_cn.strip())] = (market_brand.strip(),
                                                           market_model.strip())
    return out


def build(args):
    if not os.path.exists(BASE_SNAPSHOT):
        print('!! нет базового снимка %s' % BASE_SNAPSHOT)
        print('   это каталог ДО слияния с МИИТ; возьмите его из истории git:')
        print('   git show HEAD:assets/cars.csv > data/cars_base.csv')
        return 1
    base_hdr, base_rows = read_csv(BASE_SNAPSHOT)
    miit_hdr, miit_rows = read_csv(MIIT_ROWS)
    if not miit_hdr:
        print('!! нет файла %s - сначала запустите tools/miit_import.py' % MIIT_ROWS)
        return 1
    aliases = {} if args.no_aliases else load_aliases()

    base_cols = base_hdr or BASE_COLUMNS
    idx = dict((name, base_cols.index(name)) for name in base_cols)

    def base_get(row, name):
        i = idx.get(name)
        return row[i] if i is not None and i < len(row) else ''

    # какие (марка, модель) уже есть в базовом каталоге
    base_models = set()
    base_keys = set()
    for r in base_rows:
        base_models.add((norm_brand(base_get(r, 'brand')),
                         (base_get(r, 'model') or '').strip().lower()))
        base_keys.add(key3(base_get(r, 'brand'), base_get(r, 'model'),
                           base_get(r, 'modification')))

    mi = dict((name, miit_hdr.index(name)) for name in miit_hdr)

    def mi_get(row, name):
        i = mi.get(name)
        return row[i] if i is not None and i < len(row) else ''

    # отбираем строки МИИТ, лучшие по (марка, модель, тип) - свежие по publicTime
    best = {}
    skipped_foreign = 0
    renamed = 0
    for r in miit_rows:
        brand = mi_get(r, 'brand')
        model = mi_get(r, 'model')
        mod = mi_get(r, 'modification')
        city = mi_get(r, 'baseCityNorm')
        hwy = mi_get(r, 'baseHighwayNorm')
        if not brand or not model:
            continue
        if not (city and hwy):
            continue                      # без пары город/трасса строка для расчёта не годится
        ali = aliases.get((brand, model))
        if ali:
            brand, model = ali
            renamed += 1
        is_cn = brand in CN_BRANDS or ali is not None
        if not is_cn and not args.include_foreign:
            skipped_foreign += 1
            continue
        k = key3(brand, model, mod)
        prev = best.get(k)
        if prev is None or (mi_get(r, 'publicTime') or '') > (mi_get(prev[0], 'publicTime') or ''):
            # Рядом со строкой храним переименованные марку и модель: в самой
            # строке остались китайские названия, при записи их надо подменить.
            best[k] = (r, brand, model)

    add_rows = []
    dup_base = 0
    for k, item in best.items():
        if k in base_keys:
            dup_base += 1
            continue
        add_rows.append(item)

    # шаблонные строки базового каталога по китайским маркам
    drop_rows = []
    if args.replace_cn:
        added_models = set((norm_brand(b), (m or '').strip().lower())
                           for _, b, m in add_rows)
        for r in base_rows:
            b = base_get(r, 'brand')
            m = (base_get(r, 'model') or '').strip().lower()
            if b in CN_BRANDS and (norm_brand(b), m) in added_models:
                drop_rows.append(r)

    add_rows.sort(key=lambda item: (item[1], item[2],
                                    mi_get(item[0], 'modification')))
    keep_rows = [r for r in base_rows if r not in drop_rows]

    out_cols = list(base_cols)
    for c in PROVENANCE:
        if c not in out_cols:
            out_cols.append(c)

    def out_row(r, is_miit):
        if not is_miit:
            row = list(r) + [''] * (len(out_cols) - len(r))
            if 'normSource' in out_cols:
                row[out_cols.index('normSource')] = 'FuelMaster'
            return row
        row = []
        for c in out_cols:
            row.append(mi_get(r, c))
        return row

    def miit_out_row(item):
        r, brand, model = item
        row = [mi_get(r, c) for c in out_cols]
        for name, value in (('brand', brand), ('model', model)):
            if name in out_cols:
                row[out_cols.index(name)] = value
        return row

    out = [out_row(r, False) for r in keep_rows]
    out += [miit_out_row(item) for item in add_rows]

    print('базовый каталог: %d строк, %d марок'
          % (len(base_rows), len(set(norm_brand(base_get(r, 'brand')) for r in base_rows))))
    print('строк МИИТ всего: %d | пропущено (не CN-марки): %d' % (len(miit_rows), skipped_foreign))
    print('к добавлению: %d | уже есть в базе (по марке+модели+типу): %d' % (len(add_rows), dup_base))
    print('переименовано в рыночные названия: %d' % renamed)
    print('к удалению шаблонных строк по CN-маркам: %d' % len(drop_rows))
    added_brands = set(norm_brand(b) for _, b, _ in add_rows)
    base_brands = set(norm_brand(base_get(r, 'brand')) for r in base_rows)
    print('новых марок: %d -> %s' % (len(added_brands - base_brands),
                                    ', '.join(sorted(added_brands - base_brands))[:400]))
    cls = collections.Counter(mi_get(item[0], 'vehicleType') for item in add_rows)
    print('классы добавляемых строк: %s' % dict(cls))

    if args.dry_run:
        print('\n[пробный запуск] файл %s не изменён' % CATALOG)
        return 0

    # Одна прокручиваемая копия предыдущего файла: серия копий с отметками
    # времени только засоряла каталог (история есть в git).
    backup = os.path.join(DATA, 'cars_prev.csv')
    shutil.copy2(CATALOG, backup)
    print('предыдущий каталог сохранён: %s' % backup)

    buf = io.StringIO()
    w = csv.writer(buf, lineterminator='\n')
    w.writerow(out_cols)
    for row in out:
        w.writerow(row)
    with io.open(CATALOG, 'w', encoding='utf-8', newline='') as fh:
        fh.write(buf.getvalue())
    print('\nзаписано: %s' % CATALOG)
    print('было строк: %d -> стало: %d' % (len(base_rows), len(out)))
    print('размер: %.1f МБ' % (len(buf.getvalue().encode('utf-8')) / 1048576.0))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true', help='только отчёт')
    ap.add_argument('--replace-cn', action='store_true',
                    help='убрать шаблонные строки базового каталога по CN-маркам')
    ap.add_argument('--include-foreign', action='store_true',
                    help='добавлять и некитайские марки (нормы иной комплектации)')
    ap.add_argument('--no-aliases', action='store_true',
                    help='не переименовывать модели в рыночные названия')
    args = ap.parse_args()
    return build(args)


if __name__ == '__main__':
    sys.exit(main())
