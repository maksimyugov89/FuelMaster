#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Сбор ОФИЦИАЛЬНЫХ данных о расходе топлива из государственной системы КНР
"中国汽车能源消耗量查询" (Министерство промышленности и информатизации КНР, МИИТ).

Источник: https://yhgscx.miit.gov.cn/fuel-consumption-web/
Открытая государственная система публичного поиска: производитель ОБЯЗАН сдать
данные по каждому одобренному типу ТС, МИИТ публикует их ежемесячно.
Ответ - машиночитаемый JSON. Это первоисточник, не пересказ и не агрегатор.

РЕЕСТРЫ (из /fuel-consumption-web/js/app.js):
  queryList     - 轻型汽车燃料消耗量通告 (能耗标识). ~105 000 записей.
                  Поля: urbanConditions (город) / suburbanConditions (пригород) /
                  comprehensiveConditions (смешанный) + workConditionVos по циклам
                  WLTC / NEDC. Единица измерения - л/100км.
  queryNewList  - 新版油耗数据. ~33 000 записей, все классы ТС, включая
                  коммерческие. Поля: synthesisFuelConsumption (комбинированный),
                  lowSpeed/moderateSpeed/highSpeed/superSpeedFuelConsumption
                  (четыре фазы WLTC!), energyType, vehicleType, co2Emission,
                  electricEnergyConsumption, drivingRange, engineModel,
                  maximumTotalDesignMass, completeVehicleQuality.

РЕЖИМЫ
  --all                 полный проход реестра БЕЗ фильтра (максимальный охват)
  --brand <CN>          одна марка (китайское имя, для queryList - с суффиксом 牌)
  --producer            трактовать --brand как имя производителя (oversrasName)
  --probe               только количество записей по списку марок

Каждая страница сохраняется отдельным файлом <registry>/p%06d.json -
это делает сбор возобновляемым: повторный запуск докачивает пропущенные
страницы и не может создать дубли или сдвиг нумерации.

Примеры:
    python tools/miit_fetch.py --registry both --all --workers 3
    python tools/miit_fetch.py --registry queryList --brand 哈弗牌
    python tools/miit_fetch.py --registry both --probe
    python tools/miit_fetch.py --registry both --merge
"""

import argparse
import gzip
import json
import os
import ssl
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API = ('https://yhgscx.miit.gov.cn/fuel-consumption-center'
       '/fuel-consumption-center/fcSearchCtr/')
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Content-Type': 'application/json;charset=UTF-8',
    'Accept': 'application/json, text/plain, */*',
    'Origin': 'https://yhgscx.miit.gov.cn',
    'Referer': 'https://yhgscx.miit.gov.cn/fuel-consumption-web/',
}
REGISTRIES = ('queryList', 'queryNewList')
PAGE_SIZE = 200         # сервер принимает до 200
SLEEP = 1.0             # пауза между запросами в одном потоке, сек
RETRIES = 5

DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           '..', 'data', 'miit')

# Марки: китайское имя (для запроса) -> наши имена в базе.
BRANDS = [
    ('哈弗牌', 'Haval'), ('长城牌', 'Great Wall'), ('魏牌', 'Wey'),
    ('坦克牌', 'Tank'), ('欧拉牌', 'Ora'),
    ('吉利牌', 'Geely'), ('领克牌', 'Lynk & Co'), ('几何牌', 'Geometry'),
    ('比亚迪牌', 'BYD'), ('腾势牌', 'Denza'), ('方程豹牌', 'Fangchengbao'),
    ('奇瑞牌', 'Chery'), ('星途牌', 'Exeed'), ('捷途牌', 'Jetour'),
    ('开瑞牌', 'Karry'), ('智界牌', 'Luxeed'),
    ('长安牌', 'Changan'), ('欧尚牌', 'Oshan'), ('深蓝牌', 'Deepal'),
    ('启源牌', 'Neo'), ('阿维塔牌', 'Avatr'),
    ('红旗牌', 'Hongqi'), ('奔腾牌', 'Bestune'),
    ('宝骏牌', 'Baojun'), ('五菱牌', 'Wuling'),
    ('荣威牌', 'Roewe'), ('名爵牌', 'MG'), ('飞凡牌', 'Rising'),
    ('大通牌', 'Maxus'), ('宝沃牌', 'Borgward'),
    ('东风牌', 'Dongfeng'), ('岚图牌', 'Voyah'), ('猛士牌', 'Mengshi'),
    ('风神牌', 'Aeolus'), ('风行牌', 'Forthing'),
    ('蔚来牌', 'NIO'), ('乐道牌', 'Onvo'), ('理想牌', 'Li Auto'),
    ('小鹏牌', 'XPeng'), ('零跑牌', 'Leapmotor'), ('极氪牌', 'Zeekr'),
    ('合创牌', 'Hycan'), ('哪吒牌', 'Neta'),
    ('广汽牌', 'GAC'), ('传祺牌', 'GAC Trumpchi'), ('埃安牌', 'GAC Aion'),
    ('昊铂牌', 'GAC Hyptec'), ('北汽牌', 'BAIC'), ('极狐牌', 'Arcfox'),
    ('北京牌', 'BAIC (Beijing)'), ('瑞驰牌', 'Rox'),
    ('江淮牌', 'JAC'), ('思皓牌', 'Sehol'), ('钇为牌', 'Yiwei'),
    ('福田牌', 'Foton'), ('众泰牌', 'Zotye'), ('中华牌', 'Brilliance'),
    ('海马牌', 'Haima'), ('东南牌', 'Soueast'), ('赛力斯牌', 'Seres'),
    ('问界牌', 'Aito'), ('斯威牌', 'SWM'), ('凯翼牌', 'Kaiyi'),
    ('力帆牌', 'Lifan'), ('启辰牌', 'Venucia'), ('远程牌', 'Farizon'),
    ('解放牌', 'FAW Jiefang'), ('陕汽牌', 'Shacman'), ('重汽牌', 'Sinotruk'),
    ('宇通牌', 'Yutong'), ('金龙牌', 'King Long'), ('金旅牌', 'Golden Dragon'),
    ('亚星牌', 'Yaxing'), ('安凯牌', 'Ankai'), ('中通牌', 'Zhongtong'),
    ('一汽牌', 'FAW'), ('江铃牌', 'JMC'), ('陆风牌', 'Landwind'),
    ('鑫源牌', 'Shineray'), ('金杯牌', 'Jinbei'), ('吉奥牌', 'Gonow'),
    ('野马牌', 'Yema'), ('云度牌', 'Yudo'), ('知豆牌', 'Zhido'),
    ('威马牌', 'WM Motor'), ('天际牌', 'Enovate'), ('创维牌', 'Skyworth'),
    ('极星牌', 'Polestar'), ('极越牌', 'Jiyue'),
]

# Производители (oversrasName) - надёжнее там, где марка названа иначе
# (Tank под 长城汽车, Trumpchi/Aion под 广汽乘用车, Forthing под 东风柳州).
PRODUCERS = [
    ('长城汽车', 'Great Wall (incl. Tank/Wey/Ora)'),
    ('吉利汽车', 'Geely (incl. Lynk & Co)'),
    ('比亚迪汽车', 'BYD'), ('奇瑞汽车', 'Chery (incl. Exeed/Jetour)'),
    ('长安汽车', 'Changan (incl. Oshan)'), ('广汽乘用车', 'GAC Trumpchi/Aion'),
    ('广州汽车', 'GAC'), ('上汽通用五菱', 'Wuling / Baojun'),
    ('华晨', 'Brilliance'), ('东风柳州', 'Forthing'), ('东风汽车', 'Dongfeng'),
    ('一汽', 'FAW (incl. Bestune/Hongqi)'), ('江淮汽车', 'JAC'),
    ('北汽', 'BAIC'), ('上汽集团', 'SAIC (Roewe/MG/Maxus)'),
    ('蔚来', 'NIO'), ('理想汽车', 'Li Auto'), ('小鹏汽车', 'XPeng'),
    ('零跑汽车', 'Leapmotor'), ('浙江极氪', 'Zeekr'), ('赛力斯', 'Seres'),
    ('宇通', 'Yutong'), ('金龙', 'King Long'), ('中国重汽', 'Sinotruk'),
    ('陕汽', 'Shacman'), ('北汽福田', 'Foton'), ('江铃', 'JMC'),
]

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE

_lock = threading.Lock()
_stat = {'ok': 0, 'skip': 0, 'fail': 0, 'records': 0}


def _log(msg):
    with _lock:
        print('[%s] %s' % (time.strftime('%H:%M:%S'), msg), flush=True)


def _post(endpoint, payload, timeout=120):
    data = json.dumps(payload).encode('utf-8')
    last = None
    for attempt in range(RETRIES):
        req = urllib.request.Request(API + endpoint, data=data,
                                     headers=HEADERS, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=timeout,
                                        context=_CTX) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except (urllib.error.URLError, urllib.error.HTTPError,
                TimeoutError, json.JSONDecodeError, OSError) as exc:
            last = exc
            time.sleep(min(2 ** attempt, 20))
    raise RuntimeError('запрос %s не удался: %s' % (endpoint, last))


def _payload(page, page_size=PAGE_SIZE, brand='', producer='', **extra):
    p = {'currentPage': page, 'pageSize': page_size,
         'oversrasName': producer, 'reportType': '', 'vehicleType': '',
         'vehicleBrand': brand, 'displacement': '', 'drivingType': '',
         'usualName': '', 'drivingRange': '', 'activationDate': '',
         'vehicleModel': '', 'energyType': '',
         'publicTimeStart': '', 'publicTimeEnd': ''}
    p.update(extra)
    return p


def count(registry, brand='', producer=''):
    info = _post(registry, _payload(1, 1, brand, producer))['info']
    return int(info.get('totalSize') or 0)


def probe(brands, producer_mode):
    print('%-14s %-42s %12s' % ('МАРКА(CN)', 'НАША БАЗА', 'ЗАПИСЕЙ'))
    print('-' * 70)
    total = 0
    for cn, own in brands:
        try:
            n = count('queryList', '' if producer_mode else cn,
                      cn if producer_mode else '')
        except Exception as exc:                       # noqa: BLE001
            n = 'ОШИБКА: %s' % exc
        print('%-14s %-42s %12s' % (cn, own, n))
        if isinstance(n, int):
            total += n
        time.sleep(SLEEP)
    print('-' * 70)
    print('ИТОГО по списку: %s' % total)


def _page_path(out_dir, registry, page):
    d = os.path.join(out_dir, registry)
    return os.path.join(d, 'p%06d.json' % page)


def _fetch_page(registry, page, page_size, out_dir, brand='', producer=''):
    path = _page_path(out_dir, registry, page)
    if os.path.exists(path) and os.path.getsize(path) > 2:
        with _lock:
            _stat['skip'] += 1
        return
    try:
        info = _post(registry, _payload(page, page_size, brand,
                                        producer))['info']
    except Exception as exc:                           # noqa: BLE001
        with _lock:
            _stat['fail'] += 1
            _log('  ОШИБКА стр.%d (%s): %s' % (page, registry, exc))
        return
    batch = info.get('list') or []
    payload = {'registry': registry, 'page': page, 'pageSize': page_size,
               'totalSize': info.get('totalSize'), 'pages': info.get('pages'),
               'fetchedAt': time.strftime('%Y-%m-%dT%H:%M:%S'),
               'list': batch}
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(payload, fh, ensure_ascii=False)
    os.replace(tmp, path)
    with _lock:
        _stat['ok'] += 1
        _stat['records'] += len(batch)
        done = _stat['ok']
    if done % 10 == 0 or page <= 3:
        _log('  %s: страниц скачано %d, записей %d'
             % (registry, done, _stat['records']))


def fetch_all(registry, out_dir, page_size, workers, brand='', producer='',
              max_pages=None):
    os.makedirs(os.path.join(out_dir, registry), exist_ok=True)
    total = count(registry, brand, producer)
    pages = (total + page_size - 1) // page_size
    if max_pages:
        pages = min(pages, max_pages)
    _log('%s: записей %d, страниц %d (по %d)' % (registry, total, pages, page_size))
    todo = [p for p in range(1, pages + 1)
            if not os.path.exists(_page_path(out_dir, registry, p))]
    _log('%s: осталось скачать %d страниц (уже есть %d)'
         % (registry, len(todo), pages - len(todo)))

    def work(page):
        _fetch_page(registry, page, page_size, out_dir, brand, producer)
        time.sleep(SLEEP)

    with ThreadPoolExecutor(max_workers=workers) as ex:
        list(ex.map(work, todo))
    return total, pages


def merge(out_dir, registry):
    """Склеивает страницы в один .jsonl(+ .gz). Возвращает число записей."""
    d = os.path.join(out_dir, registry)
    if not os.path.isdir(d):
        _log('нет каталога %s' % d)
        return 0
    files = sorted(f for f in os.listdir(d)
                   if f.startswith('p') and f.endswith('.json'))
    seen = set()
    out_path = os.path.join(out_dir, '%s.jsonl' % registry)
    gz_path = out_path + '.gz'
    n = 0
    with open(out_path, 'w', encoding='utf-8', newline='\n') as fh:
        for f in files:
            with open(os.path.join(d, f), 'r', encoding='utf-8') as src:
                payload = json.load(src)
            for rec in payload.get('list') or []:
                key = rec.get('uniqId') or rec.get('uuid') or rec.get('applyId')
                if key and key in seen:
                    continue
                if key:
                    seen.add(key)
                fh.write(json.dumps(rec, ensure_ascii=False) + '\n')
                n += 1
    with open(out_path, 'rb') as src, gzip.open(gz_path, 'wb') as dst:
        dst.write(src.read())
    _log('%s: %d записей -> %s (+ .gz)' % (registry, n, out_path))
    return n


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--registry', default='queryList',
                    help='queryList | queryNewList | both')
    ap.add_argument('--all', action='store_true',
                    help='полный проход реестра без фильтра')
    ap.add_argument('--brand', default=None,
                    help='китайское имя марки/производителя')
    ap.add_argument('--producer', action='store_true')
    ap.add_argument('--probe', action='store_true')
    ap.add_argument('--merge', action='store_true')
    ap.add_argument('--workers', type=int, default=3)
    ap.add_argument('--page-size', type=int, default=PAGE_SIZE)
    ap.add_argument('--max-pages', type=int, default=None)
    ap.add_argument('--out', default=None)
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out or DEFAULT_OUT)
    os.makedirs(out_dir, exist_ok=True)
    regs = REGISTRIES if args.registry == 'both' else (args.registry,)

    if args.probe:
        probe(PRODUCERS if args.producer else BRANDS, args.producer)
        return 0

    if args.merge:
        for r in regs:
            merge(out_dir, r)
        return 0

    if not args.all and not args.brand:
        ap.error('нужен --all, --brand <CN>, --probe или --merge')

    for r in regs:
        if args.all:
            fetch_all(r, out_dir, args.page_size, args.workers,
                      max_pages=args.max_pages)
        else:
            own = args.brand
            fetch_all(r, out_dir, args.page_size, args.workers,
                      brand='' if args.producer else own,
                      producer=own if args.producer else '',
                      max_pages=args.max_pages)
    _log('готово: скачано %d стр., пропущено %d, ошибок %d, записей %d'
         % (_stat['ok'], _stat['skip'], _stat['fail'], _stat['records']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
