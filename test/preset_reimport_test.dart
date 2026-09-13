import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/initial_data.dart';

/// Каталог авто (F-3) проверяется на настоящем SQLite и настоящем CSV:
/// мок здесь ничего не доказывал бы — перелив трогает данные пользователя.
void main() {
  late String csv;
  late int csvRows;

  Future<String> helperDbPath() async =>
      p.join(await getDatabasesPath(), 'fuelmaster.db');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Свой каталог баз: тест-файлы идут параллельно и не должны делить файл БД.
    final dir = Directory.systemTemp.createTempSync('fm_presets_');
    await databaseFactory.setDatabasesPath(dir.path);

    final file = File('assets/cars.csv');
    expect(file.existsSync(), isTrue, reason: 'нужен реальный assets/cars.csv');
    csv = file.readAsStringSync();
    // Строк данных = всего строк минус шапка (пустые строки не в счёт).
    csvRows = csv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .length -
        1;

    final path = await helperDbPath();
    final dbFile = File(path);
    if (dbFile.existsSync()) dbFile.deleteSync();

    final db = await DatabaseHelper.instance.database;

    // Машина пользователя и запись истории — их перелив трогать не должен.
    final userId = await db.insert('cars', {
      'brand': 'Toyota',
      'model': 'Camry XV70',
      'license_plate': 'A123BC',
      'base_rate_city': 8.4,
      'base_rate_highway': 5.7,
      'vehicle_type': 'Passenger Car',
      'is_preset': 0,
    });
    await db.insert('fuel_logs', {
      'date': '2026-09-01',
      'car_id': userId,
      'initial_mileage': 1000.0,
      'final_mileage': 1500.0,
      'highway_mileage': 200.0,
      'city_mileage': 300.0,
      'initial_fuel': 40.0,
      'refuel': 45.0,
      'fuel_used': 42.0,
      'final_fuel': 43.0,
    });

    // Строка старого каталога: после перелива её быть не должно.
    await db.insert('cars', {
      'brand': 'СтараяМарка',
      'model': 'Устаревшая',
      'vehicle_type': 'Passenger Car',
      'is_preset': 1,
    });

    final ok = await InitialData.reimportPresetData(csvString: csv);
    expect(ok, isTrue, reason: 'перелив каталога должен пройти успешно');
  });

  test('перелив не трогает машины и историю пользователя', () async {
    final db = await DatabaseHelper.instance.database;

    final userCars =
        await db.query('cars', where: 'is_preset = ?', whereArgs: [0]);
    expect(userCars, hasLength(1));
    expect(userCars.first['brand'], 'Toyota');

    final logs = await db.query('fuel_logs');
    expect(logs, hasLength(1));
    expect(logs.first['fuel_used'], 42.0);

    final stale = await db.query('cars',
        where: 'brand = ?', whereArgs: ['СтараяМарка']);
    expect(stale, isEmpty, reason: 'строка старого каталога удаляется');
  });

  test('каталог перелит целиком: строк ровно сколько в CSV', () async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM cars WHERE is_preset = 1');
    expect(rows.first['cnt'], csvRows);
  });

  test('в каталоге появились марки, которых раньше не было', () async {
    final db = await DatabaseHelper.instance.database;
    final brands = (await db.query('cars',
            columns: ['brand'],
            where: 'is_preset = 1',
            distinct: true))
        .map((row) => row['brand'] as String)
        .toSet();

    expect(
      brands,
      containsAll(<String>[
        'Haval', 'Geely', 'Exeed', 'Changan', 'Omoda', 'Jaecoo', 'Jetour',
        'Tank', 'Belgee', 'Москвич', 'Solaris', 'КамАЗ', 'ЗИЛ', 'DAF', 'Dacia',
        'Isuzu', 'MG', 'BAIC',
      ]),
      reason: 'база расширена марками, которые встречаются на дорогах',
    );
    expect(brands.length, greaterThanOrEqualTo(140));

    final jolion = await db.query('cars',
        where: 'brand = ? AND model = ? AND is_preset = 1',
        whereArgs: ['Haval', 'Jolion']);
    expect(jolion, hasLength(2), reason: 'Jolion: 2WD и 4WD');
    expect(jolion.first['base_rate_city'], isNotNull);
  });

  test('в каталоге нет строк с нечисловыми нормами (регрессия качества CSV)',
      () async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('cars',
        columns: ['brand', 'model', 'base_rate_city', 'base_rate_highway',
                  'fuel_type', 'vehicle_type'],
        where: 'is_preset = 1');

    const allowedFuel = {'Б', 'Д', 'Этанол', 'Электро', 'КПГ', 'Газ'};
    const allowedType = {'Passenger Car', 'Truck', 'Bus', 'Van'};
    final bad = <String>[];

    for (final row in rows) {
      final city = row['base_rate_city'];
      final highway = row['base_rate_highway'];
      if (city is! num || highway is! num) {
        bad.add('${row['brand']} ${row['model']}: норма не число');
        continue;
      }
      if (!allowedFuel.contains(row['fuel_type'])) {
        bad.add('${row['brand']} ${row['model']}: топливо ${row['fuel_type']}');
      }
      if (!allowedType.contains(row['vehicle_type'])) {
        bad.add('${row['brand']} ${row['model']}: тип ${row['vehicle_type']}');
      }
    }
    expect(bad, isEmpty, reason: bad.take(10).join('; '));
  });

  test('повторный перелив идемпотентен', () async {
    final db = await DatabaseHelper.instance.database;
    final before = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM cars WHERE is_preset = 1');

    final ok = await InitialData.reimportPresetData(csvString: csv);
    expect(ok, isTrue);

    final after = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM cars WHERE is_preset = 1');
    expect(after.first['cnt'], before.first['cnt'],
        reason: 'каталог не должен дублироваться');
  });
}
