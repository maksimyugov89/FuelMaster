#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Преобразование сырых записей МИИТ (data/miit/*.jsonl) в каталог автомобилей
схемы FuelMaster.

Вход  - JSONL из tools/miit_fetch.py (официальные данные МИИТ КНР).
Выход - CSV, совместимый с assets/cars.csv: парсер initial_data.dart ищет
        столбцы ПО ИМЕНИ, поэтому добавленные колонки ничего не ломают,
        а несут происхождение нормы (источник, цикл, дата публикации).

Принципы:
  * ничего не выдумываем: пусто в первоисточнике - пусто в CSV;
  * значения не подгоняем под "похожие" машины;
  * у каждой строки сохраняется ссылка на запись первоисточника (sourceRef).

Классификация: 乘用车（M1类）-> Passenger Car, 轻型客车（M2类）-> Bus,
轻型货车（N1类）-> Truck (как в существующем каталоге: микроавтобус = Bus).

Запуск:
    python tools/miit_import.py                 # оба реестра -> data/catalog_miit.csv
    python tools/miit_import.py --report --top 60
"""

import argparse
import collections
import csv
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')
MIIT = os.path.join(DATA, 'miit')

sys.path.insert(0, HERE)
from miit_fetch import BRANDS  # noqa: E402  единый источник списка марок

# --- карты кодов: извлечены из /fuel-consumption-web/js/app.js (13.09.2026) ---
ENERGY_TYPE_CN = {
    '1': '汽油', '2': '柴油', '3': '两用燃料', '4': '双燃料',
    '5': '不可外接充电式混合动力', '6': '可外接充电式混合动力(汽油/电)',
    '7': '可外接充电式混合动力(柴油/电)', '8': '纯电动', '9': '燃料电池',
    '10': '其它',
}
REPORT_TYPE_CN = {'1': '传统能源', '2': '混合动力电动汽车', '3': '纯电动车'}
DRIVE_TYPE_CN = {'1': '前轮驱动', '2': '后轮驱动', '3': '分时四轮驱动',
                 '4': '适时四轮驱动', '5': '全时全轮驱动', '6': '其它'}
# В каталоге FuelMaster топливо записывается словами из фиксированного набора:
# Б - бензин, Д - дизель, Газ, КПГ, Этанол, Электро (см. тест каталога).
ENERGY_TO_FUEL = {'1': 'Б', '2': 'Д', '3': 'Газ', '4': 'Газ', '5': 'Б',
                  '6': 'Б', '7': 'Д', '8': 'Электро', '9': 'Электро', '10': ''}
FUEL_BY_REPORT = {'1': '', '2': 'Б', '3': 'Электро'}


def fuel_by_class(clazz, disp):
    """Топливо, когда реестр его не называет -> (топливо, пометка).

    В реестре 能耗标识 поля топлива нет вовсе: есть только «традиционное
    топливо / гибрид / электро». Для легковых принимаем бензин (дизельных M1
    в реестре единицы), для грузовых, автобусов и фургонов - по рабочему
    объёму. Пометка уходит в колонку происхождения, чтобы в каталоге было
    видно, где значение подтверждено, а где принято по классу машины.
    """
    if clazz in ('Truck', 'Bus', 'Van'):
        if disp != '' and float(disp) >= 2000:
            return 'Д', 'принято: дизель по классу и объёму'
        return 'Б', 'принято: бензин по классу и объёму'
    return 'Б', 'принято: бензин (дизельные M1 редки)'

KV_TO_HP = 1.35962

CLASS_FROM_LABEL = {
    '乘用车（M1类）': 'Passenger Car', '乘用车(M1类)': 'Passenger Car',
    '轻型客车（M2类）': 'Bus', '轻型客车(M2类)': 'Bus',
    '轻型货车（N1类）': 'Truck', '轻型货车(N1类)': 'Truck',
    '乘用车': 'Passenger Car', '轻型客车': 'Bus', '轻型货车': 'Truck',
    '客车': 'Bus', '货车': 'Truck', 'M1': 'Passenger Car', 'M2': 'Bus',
    'N1': 'Truck',
}
CLASS_FROM_CODE = {'1': 'Passenger Car', '2': 'Bus', '3': 'Truck'}

CITY_PREFIXES = ('浙江', '合肥', '重庆', '山西', '湖北', '安徽', '四川', '广州',
                 '柳州', '保定', '芜湖', '深圳', '上海', '北京', '江苏', '山东',
                 '河北', '河南', '湖南', '福建', '广东', '陕西', '吉林', '辽宁',
                 '天津', '江西', '贵州', '云南', '广西', '海南', '甘肃', '新疆',
                 '内蒙古', '黑龙江', '中国')

EXTRA_BRANDS = {
    '奥迪': 'Audi', '宝马': 'BMW', '奔驰': 'Mercedes-Benz', '大众': 'Volkswagen',
    '丰田': 'Toyota', '本田': 'Honda', '日产': 'Nissan', '福特': 'Ford',
    '雪佛兰': 'Chevrolet', '别克': 'Buick', '现代': 'Hyundai', '起亚': 'KIA',
    '斯柯达': 'Skoda', '沃尔沃': 'Volvo', '保时捷': 'Porsche', '雷克萨斯': 'Lexus',
    '捷豹': 'Jaguar', '路虎': 'Land Rover', '马自达': 'Mazda', '三菱': 'Mitsubishi',
    '铃木': 'Suzuki', '标致': 'Peugeot', '雪铁龙': 'Citroen', '菲亚特': 'Fiat',
    '吉普': 'Jeep', '道奇': 'Dodge', '凯迪拉克': 'Cadillac', '林肯': 'Lincoln',
    '特斯拉': 'Tesla', '斯巴鲁': 'Subaru', '英菲尼迪': 'Infiniti', '雷诺': 'Renault',
    '欧宝': 'Opel', '依维柯': 'Iveco', '斯堪尼亚': 'Scania', '曼恩': 'MAN',
    '迷你': 'MINI', '捷尼赛思': 'Genesis', '讴歌': 'Acura', '萨博': 'Saab',
    '兰博基尼': 'Lamborghini', '法拉利': 'Ferrari', '玛莎拉蒂': 'Maserati',
    '宾利': 'Bentley', '劳斯莱斯': 'Rolls-Royce', '阿斯顿马丁': 'Aston Martin',
    '迈凯伦': 'McLaren', '布加迪': 'Bugatti', 'smart': 'Smart',
    '捷豹路虎': 'Jaguar Land Rover',
    # --- суббренды китайских групп (в реестре идут под производителем) ---
    '上汽大通': 'Maxus', '大通': 'Maxus', '荣威': 'Roewe', '名爵': 'MG',
    '五菱': 'Wuling', '宝骏': 'Baojun', '奔腾': 'Bestune', '红旗': 'Hongqi',
    '风行': 'Forthing', '风光': 'Fengon', '风神': 'Aeolus', '瑞风': 'Refine',
    '驭胜': 'JMC', '江铃': 'JMC', '福田': 'Foton', '依维柯': 'Iveco',
    '传祺': 'GAC', '埃安': 'Aion', '深蓝': 'Deepal', '阿维塔': 'Avatr',
    '腾势': 'Denza', '仰望': 'Yangwang', '方程豹': 'Fangchengbao',
    '哪吒': 'Neta', '零跑': 'Leapmotor', '蔚来': 'NIO', '小鹏': 'XPeng',
    '理想': 'Li Auto', '领克': 'Lynk & Co', '极氪': 'Zeekr', '岚图': 'Voyah',
    '飞凡': 'Rising Auto', '智己': 'IM Motors', '睿蓝': 'Livan',
    '欧萌达': 'Omoda', '杰酷': 'Jaecoo', '星途': 'Exeed', '捷途': 'Jetour',
    '坦克': 'Tank', '欧拉': 'Ora', '魏牌': 'WEY', '哈弗': 'Haval',
    '银河': 'Geely', '睿行': 'Changan', '跨越': 'Changan',
}

OUT_COLUMNS = [
    'brand', 'model', 'modification', 'cylinders', 'powerHp', 'engineVolume',
    'transmissionType', 'transmissionSpeeds', 'baseCityNorm', 'baseHighwayNorm',
    'fuelType', 'vehicleType',
    # --- ниже: происхождение нормы (лишние колонки парсер игнорирует) ---
    'baseCombinedNorm', 'testCycle', 'normSource', 'sourceRef', 'publicTime',
    'energyType', 'driveType', 'aliasCn', 'registry', 'brandCn', 'region',
    'phaseLow', 'phaseMid', 'phaseHigh', 'phaseExtra', 'electricKwh',
    'co2', 'drivingRange', 'mass',
]

_BRAND_MAP = {cn.rstrip('牌'): own for cn, own in BRANDS}
_BRAND_MAP.update(EXTRA_BRANDS)

# чем длиннее совпадение, тем оно приоритетнее
BRAND_TABLE = sorted(_BRAND_MAP.items(), key=lambda kv: -len(kv[0]))
BRAND_KEYS = [k for k, _ in BRAND_TABLE]

# Марки из дополнительного списка имеют приоритет: в совместных предприятиях
# настоящая марка идёт второй (一汽-大众 -> Volkswagen, 长安福特 -> Ford).
_PREFERRED_KEYS = set(EXTRA_BRANDS)

SUB_BRANDS = []


def _load_sub_brands():
    """data/sub_brands.csv: суббренд;написания;только_если_марка.

    Нужна там, где модель не содержит марки: X70 у Jetour, 揽月 у Exeed -
    производитель у них один (Chery), а марка в реестре не указана.
    """
    path = os.path.join(DATA, 'sub_brands.csv')
    if not os.path.exists(path):
        return []
    rules = []
    with io.open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('market_brand'):
                continue
            parts = line.split(';')
            if len(parts) < 2:
                continue
            brand = parts[0].strip()
            only = parts[2].strip() if len(parts) > 2 else ''
            for pat in parts[1].split('|'):
                pat = pat.strip().lower()
                if pat:
                    rules.append((brand, pat, only.lower()))
    return rules


SUB_BRANDS = _load_sub_brands()


def apply_sub_brand(brand, model):
    """Уточнить марку по написанию модели (X70 -> Jetour, 揽月 -> Exeed)."""
    m = (model or '').strip().lower()
    if not m:
        return brand
    bl = (brand or '').lower()
    for sub, pat, only in SUB_BRANDS:
        if only and bl and bl != only:
            continue
        if m == pat or m.startswith(pat):
            return sub
    return brand


def _num(v):
    if v is None:
        return ''
    s = str(v).strip()
    if not s:
        return ''
    try:
        return float(s)
    except ValueError:
        return ''


def _fmt(v):
    """Число -> строка без хвостовых нулей (8.90 -> 8.9)."""
    if v == '' or v is None:
        return ''
    s = ('%.3f' % float(v)).rstrip('0').rstrip('.')
    return s


def vehicle_class(vt):
    s = str(vt or '').strip()
    if s in CLASS_FROM_LABEL:
        return CLASS_FROM_LABEL[s]
    if s in CLASS_FROM_CODE:
        return CLASS_FROM_CODE[s]
    for k, v in CLASS_FROM_LABEL.items():
        if k and k in s:
            return v
    return 'Passenger Car'


def brand_in_text(text):
    """Самая подходящая известная марка внутри строки -> (CN, наше имя).

    Порядок выбора: сначала марки из дополнительного списка (в совместных
    предприятиях настоящая марка идёт второй: 一汽-大众 -> 大众,
    长安福特 -> 福特), затем - более длинное совпадение, затем - более раннее.
    Иначе «奇瑞捷豹路虎» определялось как Chery, а «长安福特» - как Changan.
    """
    s = (text or '').replace(' ', '')
    best = None
    for k in BRAND_KEYS:
        i = s.find(k)
        if i < 0:
            continue
        rank = (0 if k in _PREFERRED_KEYS else 1, -len(k), i)
        if best is None or rank < best[0]:
            best = (rank, k)
    if best is None:
        return '', ''
    return best[1], _BRAND_MAP[best[1]]


def cn_from_producer(producer):
    """Если марка не опознана - вытащить её из названия производителя."""
    s = re.sub(r'(股份有限公司|有限责任公司|有限公司|公司|集团)$', '',
               (producer or '').strip())
    for pre in CITY_PREFIXES:
        if s.startswith(pre):
            s = s[len(pre):]
            break
    for kw in ('新能源汽车', '新能源', '汽车', '车辆', '商用车', '重汽', '客车',
               '卡车', '机械', '工业', '制造'):
        if kw in s:
            head = s.split(kw)[0]
            if head:
                return head
            break
    return s


def brand_from_producer(producer):
    """Марка из названия производителя -> (CN, наше имя).

    Сначала ищем известную марку внутри строки производителя
    (一汽-大众 -> 大众, 广汽丰田 -> 丰田, 上汽通用五菱 -> 五菱), и только
    если не нашли - вытаскиваем китайское имя.
    """
    cn, own = brand_in_text(producer)
    if own:
        return cn, own
    return cn_from_producer(producer), ''


def split_brand_model(usual_name, brand_hint=''):
    """(CN-марка, модель, наше имя марки) по usualName + подсказке из vehicleBrand."""
    u = (usual_name or '').replace(' ', '').strip()
    hint = (brand_hint or '').rstrip('牌').strip()
    if hint:
        for cn, own in BRAND_TABLE:
            if hint.startswith(cn):
                rest = hint[len(cn):]
                model = u[len(hint):] if u.startswith(hint) else (rest or u)
                return cn, model.strip(), own
    for cn, own in BRAND_TABLE:
        if u.startswith(cn):
            return cn, u[len(cn):].strip(), own
    m = re.match(r'^([^\x00-\x7f]+)', u)
    cn = m.group(1) if m else ''
    return cn, u[len(cn):].strip(), ''


def clean_row(row):
    """Убрать переносы строк и управляющие символы из значений.

    В названиях реестра встречаются переводы строки (东风小康\\nC31S): внутри
    значения CSV-поля они ломают подсчёт строк и попадают в интерфейс мусором.
    """
    for k, v in list(row.items()):
        if isinstance(v, str):
            row[k] = re.sub(r'\s+', ' ', v).strip()
    return row


def common_row():
    return {c: '' for c in OUT_COLUMNS}


def new_record_info(rec):
    """Компактная выжимка из записи queryNewList для перекрёстной сверки."""
    energy = str(rec.get('energyType') or '').strip()
    synth = _num(rec.get('synthesisFuelConsumption'))
    return {
        'energyCn': ENERGY_TYPE_CN.get(energy, ''),
        'fuel': ENERGY_TO_FUEL.get(energy, ''),
        'electricKwh': _fmt(_num(rec.get('electricEnergyConsumption'))),
        'co2': _fmt(_num(rec.get('co2Emission'))),
        'range': _fmt(_num(rec.get('drivingRange'))),
        'low': _fmt(_num(rec.get('lowSpeedFuelConsumption'))),
        'mid': _fmt(_num(rec.get('moderateSpeedFuelConsumption'))),
        'high': _fmt(_num(rec.get('highSpeedFuelConsumption'))),
        'extra': _fmt(_num(rec.get('superSpeedFuelConsumption'))),
        'combined': _fmt(synth),
        'mass': _fmt(_num(rec.get('maximumTotalDesignMass'))),
    }


NOTE_CN = ('Норма производителя по китайской методике (МИИТ КНР). '
           'Комплектация CN: для версий для РФ/КЗ расход может отличаться.')


def convert_query_list(rec, energy_index, prod_brand):
    vt_label = rec.get('vehicleType')
    clazz = vehicle_class(vt_label)
    report = str(rec.get('reportType') or '').strip()
    usual = (rec.get('usualName') or '').strip()
    producer = (rec.get('oversrasName') or '').strip()
    cn_brand, model, own = split_brand_model(usual)
    if not own:
        # Марки нет в начале названия: ищем её где угодно в названии, затем -
        # в имени производителя (в т.ч. совместные предприятия:
        # 一汽-大众 -> 大众, 广汽丰田 -> 丰田, 上汽通用五菱 -> 五菱).
        bcn, bown = brand_in_text(usual)
        if bown:
            own, cn_brand = bown, (cn_brand or bcn)
        else:
            pcn, pown = brand_from_producer(producer)
            if pown:
                cn_brand, own = pcn, pown
            else:
                cn_brand = cn_brand or pcn
                own = prod_brand.get(producer, '')
        # Марка не была префиксом: моделью считаем название целиком
        # (瑞虎8 остаётся 瑞虎8, а не «8»), сняв найденную марку из начала.
        model = usual
        if bown and model.startswith(bcn):
            model = model[len(bcn):].strip()
    if not cn_brand:
        cn_brand = cn_from_producer(producer)
    disp = _num(rec.get('displacement'))
    power = _num(rec.get('ratedPower'))
    cycles = rec.get('workConditionVos') or []
    cycle = str(cycles[0].get('workConditionType') or '').strip() if cycles else ''

    row = common_row()
    row.update({
        'brand': apply_sub_brand(own or cn_brand, model),
        'model': model or (rec.get('vehicleNumber') or '').strip(),
        'modification': (rec.get('vehicleNumber') or '').strip(),
        'powerHp': _fmt(power * KV_TO_HP) if power != '' else '',
        'engineVolume': _fmt(disp / 1000.0) if disp != '' else '',
        'transmissionType': (rec.get('transmissionType') or '').strip(),
        'baseCityNorm': _fmt(_num(rec.get('urbanConditions'))),
        'baseHighwayNorm': _fmt(_num(rec.get('suburbanConditions'))),
        'baseCombinedNorm': _fmt(_num(rec.get('comprehensiveConditions'))),
        'vehicleType': clazz,
        'testCycle': cycle,
        'normSource': 'MIIT-CN 能耗标识',
        'sourceRef': rec.get('uniqId') or '',
        'publicTime': rec.get('publicTime') or '',
        'energyType': REPORT_TYPE_CN.get(report, ''),
        'registry': 'queryList',
        'brandCn': cn_brand,
        'aliasCn': usual,
    })
    if clazz == 'Passenger Car' and not row['fuelType']:
        row['fuelType'] = FUEL_BY_REPORT.get(report, '')

    # перекрёстная сверка с реестром новых данных по коду типа ТС
    info = energy_index.get(row['modification'])
    if info:
        if info['energyCn']:
            row['energyType'] = info['energyCn']
        if info['fuel']:
            row['fuelType'] = info['fuel']
        for src, dst in (('electricKwh', 'electricKwh'), ('co2', 'co2'),
                         ('range', 'drivingRange')):
            if info[src]:
                row[dst] = info[src]

    if not row['fuelType']:
        fuel, note = fuel_by_class(clazz, disp)
        row['fuelType'] = fuel
        row['energyType'] = (row['energyType'] + ' (' + note + ')'
                             if row['energyType'] else note)
    return clean_row(row)


def convert_query_new(rec):
    vt = str(rec.get('vehicleType') or '').strip()
    energy = str(rec.get('energyType') or '').strip()
    usual = (rec.get('usualName') or '').strip()
    alias = ','.join(a.strip() for a in usual.split(',') if a.strip())
    first = alias.split(',')[0] if alias else ''
    cn_brand, model, own = split_brand_model(
        first or (rec.get('productName') or ''), rec.get('vehicleBrand'))
    if not model:
        model = (rec.get('productName') or '').strip()
    disp = _num(rec.get('displacement'))
    net = _num(rec.get('maximumNetPower'))
    synth = _num(rec.get('synthesisFuelConsumption'))
    if synth == '':
        synth = _num(rec.get('energyEquivalentFuelConsumption'))

    row = common_row()
    row.update({
        'brand': apply_sub_brand(own or cn_brand, model),
        'model': model or (rec.get('vehicleModel') or '').strip(),
        'modification': (rec.get('vehicleModel') or '').strip(),
        'powerHp': _fmt(net * KV_TO_HP) if net != '' else '',
        'engineVolume': _fmt(disp / 1000.0) if disp != '' else '',
        'transmissionType': (rec.get('transmissionType') or '').strip(),
        'baseCombinedNorm': _fmt(synth),
        'fuelType': ENERGY_TO_FUEL.get(energy, ''),
        'vehicleType': vehicle_class(vt),
        'normSource': 'MIIT-CN 新版油耗数据',
        'sourceRef': rec.get('uuid') or rec.get('recordNumber') or '',
        'publicTime': rec.get('enableDate') or rec.get('issueDate') or '',
        'energyType': ENERGY_TYPE_CN.get(energy, ''),
        'driveType': DRIVE_TYPE_CN.get(str(rec.get('drivingType') or ''), ''),
        'registry': 'queryNewList',
        'brandCn': cn_brand,
        'aliasCn': alias,
        'phaseLow': _fmt(_num(rec.get('lowSpeedFuelConsumption'))),
        'phaseMid': _fmt(_num(rec.get('moderateSpeedFuelConsumption'))),
        'phaseHigh': _fmt(_num(rec.get('highSpeedFuelConsumption'))),
        'phaseExtra': _fmt(_num(rec.get('superSpeedFuelConsumption'))),
        'electricKwh': _fmt(_num(rec.get('electricEnergyConsumption'))),
        'co2': _fmt(_num(rec.get('co2Emission'))),
        'drivingRange': _fmt(_num(rec.get('drivingRange'))),
        'mass': _fmt(_num(rec.get('maximumTotalDesignMass'))),
    })
    if not row['fuelType']:
        fuel, note = fuel_by_class(row['vehicleType'], disp)
        row['fuelType'] = fuel
        row['energyType'] = (row['energyType'] + ' (' + note + ')'
                             if row['energyType'] else note)
    return clean_row(row)


def load_jsonl(path):
    with io.open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def build_context():
    """Проход 1: индекс типов ТС и карта производитель->марка."""
    energy_index = {}
    p_path = os.path.join(MIIT, 'queryNewList.jsonl')
    if os.path.exists(p_path):
        for rec in load_jsonl(p_path):
            code = (rec.get('vehicleModel') or '').strip()
            if code and code not in energy_index:
                energy_index[code] = new_record_info(rec)
        print('индекс типов ТС (queryNewList): %d' % len(energy_index))

    per_producer = collections.defaultdict(collections.Counter)
    q_path = os.path.join(MIIT, 'queryList.jsonl')
    if os.path.exists(q_path):
        for rec in load_jsonl(q_path):
            cn, _, own = split_brand_model(rec.get('usualName') or '')
            if own:
                per_producer[(rec.get('oversrasName') or '').strip()][own] += 1
    prod_brand = {}
    for prod, counter in per_producer.items():
        if not prod:
            continue
        brand, n = counter.most_common(1)[0]
        if n / sum(counter.values()) >= 0.6:
            prod_brand[prod] = brand
    print('производителей с однозначной маркой: %d' % len(prod_brand))
    return energy_index, prod_brand


def run(registries, write_csv=True, top=40):
    energy_index, prod_brand = build_context()
    rows = []
    counts = collections.Counter()
    for reg in registries:
        path = os.path.join(MIIT, '%s.jsonl' % reg)
        if not os.path.exists(path):
            print('!! нет файла %s - пропускаю' % path)
            continue
        conv = (convert_query_list if reg == 'queryList'
                else lambda r: convert_query_new(r))
        for rec in load_jsonl(path):
            if reg == 'queryList':
                rows.append(conv(rec, energy_index, prod_brand))
            else:
                rows.append(conv(rec))
            counts[reg] += 1
        print('%-14s записей: %d' % (reg, counts[reg]))

    filled = lambda r, k: r[k] not in ('', None)  # noqa: E731
    brands = collections.Counter(r['brand'] for r in rows if r['brand'])
    classes = collections.Counter(r['vehicleType'] for r in rows)
    cycles = collections.Counter(r['testCycle'] or '(не указан)' for r in rows)
    print('\nВСЕГО строк: %d' % len(rows))
    print('марок: %d | без марки: %d' % (len(brands),
                                         sum(1 for r in rows if not r['brand'])))
    print('классы: %s' % dict(classes))
    print('цикл: %s' % dict(cycles))
    print('город+трасса: %d | смешанный: %d | тип энергии: %d'
          % (sum(1 for r in rows if filled(r, 'baseCityNorm')),
             sum(1 for r in rows if filled(r, 'baseCombinedNorm')),
             sum(1 for r in rows if filled(r, 'energyType'))))

    if write_csv:
        out = os.path.join(DATA, 'catalog_miit.csv')
        os.makedirs(DATA, exist_ok=True)
        with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
            w = csv.DictWriter(fh, fieldnames=OUT_COLUMNS)
            w.writeheader()
            w.writerows(rows)
        print('\nзаписано: %s (%d строк)' % (out, len(rows)))
    return rows, brands, classes


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--registry', default='both',
                    choices=['queryList', 'queryNewList', 'both'])
    ap.add_argument('--report', action='store_true', help='отчёт без записи CSV')
    ap.add_argument('--top', type=int, default=40)
    args = ap.parse_args()
    regs = (('queryList', 'queryNewList') if args.registry == 'both'
            else (args.registry,))
    rows, brands, classes = run(regs, write_csv=not args.report, top=args.top)
    print('\nТОП-%d марок по числу записей:' % args.top)
    for b, n in brands.most_common(args.top):
        print('  %-24s %6d' % (b or '(без марки)', n))
    return 0


if __name__ == '__main__':
    sys.exit(main())
