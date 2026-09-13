import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelmaster/utils/database_helper.dart';

/// Схема БД **версии 6** — такой её видели пользователи до апгрейда.
/// Колонки, добавленные миграциями 7…12 (weather_multiplier, base_city_norm,
/// base_highway_norm, total_mileage), здесь намеренно отсутствуют: именно на
/// этом пути приложение раньше падало с "duplicate column name".
const List<String> _schemaV6 = <String>[
  '''
  CREATE TABLE cars (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    license_plate TEXT,
    generation TEXT,
    modification TEXT,
    year_from TEXT,
    year_to TEXT,
    engine_volume REAL,
    power_hp REAL,
    power_kw REAL,
    fuel_type TEXT,
    transmission_type TEXT,
    transmission_speeds INTEGER,
    base_rate_city REAL,
    base_rate_highway REAL,
    base_rate_combined REAL,
    vehicle_type TEXT,
    cylinders TEXT,
    is_preset INTEGER DEFAULT 0,
    passenger_capacity INTEGER,
    heater_fuel_consumption REAL,
    fuel_consumption_per_ton_km REAL,
    trailer_weight REAL,
    fuel_consumption_per_load REAL,
    load_capacity REAL,
    battery_capacity_kwh REAL,
    last_modified INTEGER
  )
  ''',
  '''
  CREATE TABLE fuel_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    car_id INTEGER NOT NULL,
    license_plate TEXT,
    initial_mileage REAL NOT NULL,
    final_mileage REAL NOT NULL,
    highway_mileage REAL NOT NULL,
    city_mileage REAL NOT NULL,
    initial_fuel REAL NOT NULL,
    refuel REAL NOT NULL,
    fuel_used REAL NOT NULL,
    final_fuel REAL NOT NULL,
    conditions_applied TEXT,
    correction_factor REAL,
    heater_operating_time REAL,
    last_modified INTEGER
  )
  ''',
];

/// Путь, который использует сам DatabaseHelper (он берёт его из
/// getDatabasesPath() + 'fuelmaster.db'), — нужен для сквозного теста.
Future<String> _helperDbPath() async =>
    p.join(await getDatabasesPath(), 'fuelmaster.db');

/// Отдельный путь для тестов, которые не должны пересекаться между собой.
String _tempDbPath([String name = 'legacy.db']) {
  final dir = Directory.systemTemp.createTempSync('fm_migrations_');
  return p.join(dir.path, name);
}

/// Создаёт БД версии 6 с одной машиной и одной записью истории.
Future<void> _createLegacyDatabase(String path) async {
  final legacy = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 6,
      onCreate: (db, version) async {
        for (final statement in _schemaV6) {
          await db.execute(statement);
        }
      },
    ),
  );

  await legacy.insert('cars', {
    'brand': 'Toyota',
    'model': 'Camry XV70',
    'license_plate': 'A123BC',
    'base_rate_city': 8.4,
    'base_rate_highway': 5.7,
    'vehicle_type': 'Passenger Car',
    'is_preset': 0,
    'last_modified': 1700000000000,
  });
  await legacy.insert('fuel_logs', {
    'date': '2026-01-15',
    'car_id': 1,
    'license_plate': 'A123BC',
    'initial_mileage': 10000.0,
    'final_mileage': 10500.0,
    'highway_mileage': 300.0,
    'city_mileage': 200.0,
    'initial_fuel': 40.0,
    'refuel': 30.0,
    'fuel_used': 35.0,
    'final_fuel': 35.0,
    'last_modified': 1700000000000,
  });

  await legacy.close();
}

/// Открывает «чистую» БД со схемой v6 без указания версии.
Future<Database> _openSchemaV6(String path) async {
  final db = await databaseFactory.openDatabase(path);
  for (final statement in _schemaV6) {
    await db.execute(statement);
  }
  return db;
}

Future<Set<String>> _columnsOf(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((row) => row['name'] as String).toSet();
}

Future<Set<String>> _tables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return rows.map((row) => row['name'] as String).toSet();
}

Future<int> _countWeatherCoefficients(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS cnt FROM weather_coefficients',
  );
  return (rows.first['cnt'] as int?) ?? 0;
}

void main() {
  // Тесты работают на настоящем SQLite (sqflite_common_ffi), а не на моках.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Миграции БД', () {
    test('апгрейд v6 → v12 доводит схему до актуальной и не теряет данные',
        () async {
      final path = await _helperDbPath();
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      await _createLegacyDatabase(path);

      // Реальное открытие через DatabaseHelper: до правки A-4 здесь падало
      // "duplicate column name: weather_multiplier" и приложение не открывало БД.
      final cars = await DatabaseHelper.instance.getUserCars();
      expect(cars, hasLength(1));
      expect(cars.first.brand, 'Toyota');

      final db = await databaseFactory.openDatabase(path);
      addTearDown(db.close);

      final tables = await _tables(db);
      expect(
        tables,
        containsAll(<String>[
          'cars',
          'fuel_logs',
          'locations',
          'weather_coefficients',
        ]),
      );

      final logColumns = await _columnsOf(db, 'fuel_logs');
      expect(
        logColumns,
        containsAll(<String>[
          'weather_multiplier',
          'base_city_norm',
          'base_highway_norm',
          'total_mileage',
          'last_modified',
        ]),
      );

      final rows = await db.query('fuel_logs');
      expect(rows, hasLength(1));
      expect(rows.first['fuel_used'], 35.0);
    });

    test('повторный прогон миграций идемпотентен (регрессия A-4)', () async {
      final db = await _openSchemaV6(_tempDbPath());
      addTearDown(db.close);

      // Прогоняем весь путь миграций 6 → 12 дважды.
      await DatabaseHelper.runMigrationsForTesting(db, 6, 12);

      final logColumns = await db.rawQuery('PRAGMA table_info(fuel_logs)');
      final weatherColumns =
          logColumns.where((row) => row['name'] == 'weather_multiplier');
      expect(
        weatherColumns,
        hasLength(1),
        reason: 'колонка weather_multiplier должна добавляться один раз',
      );

      final afterFirst = await _countWeatherCoefficients(db);
      expect(afterFirst, greaterThan(0),
          reason: 'коэффициенты погоды должны быть заполнены');

      await DatabaseHelper.runMigrationsForTesting(db, 6, 12);

      final afterSecond = await _countWeatherCoefficients(db);
      expect(
        afterSecond,
        afterFirst,
        reason: 'повторная миграция не должна дублировать коэффициенты',
      );
    });

    test('миграция не падает на БД, где колонки уже добавлены', () async {
      final db = await _openSchemaV6(_tempDbPath('already_migrated.db'));
      addTearDown(db.close);

      // Пользователь, у которого схема уже новее: колонки есть, версия — нет.
      await db.execute(
          'ALTER TABLE fuel_logs ADD COLUMN weather_multiplier REAL');
      await db.execute('ALTER TABLE fuel_logs ADD COLUMN base_city_norm REAL');
      await db.execute(
          'ALTER TABLE fuel_logs ADD COLUMN base_highway_norm REAL');
      await db.execute('ALTER TABLE fuel_logs ADD COLUMN total_mileage REAL');
      await db.execute('''
        CREATE TABLE locations (
          city TEXT PRIMARY KEY,
          latitude REAL,
          longitude REAL,
          timezone TEXT,
          last_weather_update TEXT,
          weather_data TEXT
        )
      ''');

      await db.insert('cars', {
        'brand': 'Kia',
        'model': 'Rio',
        'base_rate_city': 7.0,
        'base_rate_highway': 5.0,
        'vehicle_type': 'Passenger Car',
        'is_preset': 0,
      });

      await DatabaseHelper.runMigrationsForTesting(db, 1, 12);

      final cars = await db.query('cars');
      expect(cars, hasLength(1));
      expect(cars.first['brand'], 'Kia');
    });
  });
}
