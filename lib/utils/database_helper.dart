import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:meta/meta.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  // ✨ FIX: Увеличена версия БД для добавления колонки total_mileage
  static const int _dbVersion = 12; 

  @visibleForTesting
  static void setDatabaseForTesting(Database db) {
    _database = db;
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fuelmaster.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        car_id INTEGER NOT NULL,
        license_plate TEXT,
        initial_mileage REAL NOT NULL,
        final_mileage REAL NOT NULL,
        total_mileage REAL,
        highway_mileage REAL NOT NULL,
        city_mileage REAL NOT NULL,
        initial_fuel REAL NOT NULL,
        refuel REAL NOT NULL,
        fuel_used REAL NOT NULL,
        final_fuel REAL NOT NULL,
        conditions_applied TEXT,
        correction_factor REAL,
        heater_operating_time REAL,
        last_modified INTEGER,
        weather_multiplier REAL,
        base_city_norm REAL,
        base_highway_norm REAL
      )
    ''');

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

    await _createWeatherCoefficientsTable(db);

    logger.d('Database created with version $version');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN license_plate TEXT');
        logger.d('Added license_plate column to fuel_logs table');
      } catch (e) {
        logger.e('Error adding license_plate column: $e');
        rethrow;
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE cars ADD COLUMN year_from TEXT');
        await db.execute('ALTER TABLE cars ADD COLUMN year_to TEXT');
        logger.d('Added year_from and year_to columns to cars table');
      } catch (e) {
        logger.e('Error adding year_from and year_to columns: $e');
        rethrow;
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE cars ADD COLUMN power_kw REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN passenger_capacity INTEGER');
        await db.execute('ALTER TABLE cars ADD COLUMN heater_fuel_consumption REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN fuel_consumption_per_ton_km REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN trailer_weight REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN fuel_consumption_per_load REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN load_capacity REAL');
        await db.execute('ALTER TABLE cars ADD COLUMN battery_capacity_kwh REAL');
        logger.d('Added new columns for vehicle types to cars table');
      } catch (e) {
        logger.e('Error adding new columns for vehicle types: $e');
        rethrow;
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN correction_factor REAL');
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN heater_operating_time REAL');
        logger.d('Added correction_factor and heater_operating_time columns to fuel_logs table');
      } catch (e) {
        logger.e('Error adding correction_factor and heater_operating_time columns: $e');
        rethrow;
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE cars ADD COLUMN last_modified INTEGER');
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN last_modified INTEGER');
        logger.d('Added last_modified columns to cars and fuel_logs tables');
      } catch (e) {
        logger.e('Error adding last_modified columns: $e');
        rethrow;
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN weather_multiplier REAL');
        logger.d('Added weather_multiplier column to fuel_logs table (upgrade <7)');
      } catch (e) {
        logger.e('Error adding weather_multiplier column (<7): $e');
        rethrow;
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN weather_multiplier REAL');
        logger.d('Added weather_multiplier column to fuel_logs table (upgrade <8)');
      } catch (e) {
        logger.e('Error adding weather_multiplier column (<8): $e');
        rethrow;
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN base_city_norm REAL');
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN base_highway_norm REAL');
        logger.d('Added base_city_norm and base_highway_norm columns to fuel_logs table');
      } catch (e) {
        logger.e('Error adding base_city_norm and base_highway_norm columns: $e');
        rethrow;
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE fuel_logs ADD COLUMN total_mileage REAL');
        logger.d('Added total_mileage column to fuel_logs table');
      } catch (e) {
        logger.e('Error adding total_mileage column: $e');
        rethrow;
      }
    }
    if (oldVersion < 11) {
    try {
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
      logger.d('Created locations table for existing users');
    } catch (e) {
      logger.e('Error creating locations table: $e');
      rethrow;
    }
  }

    if (oldVersion < 12) {
    try {
      await _createWeatherCoefficientsTable(db);
    } catch (e) {
      logger.e('Error creating weather_coefficients table: $e');
      rethrow;
    }
  }

  logger.d('Database upgraded from version $oldVersion to $newVersion');
}

  Future<List<String>> getAllPresetBrands() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        columns: ['brand'],
        where: 'is_preset = ?',
        whereArgs: [1],
        distinct: true,
      );
      final brands = maps.map((map) => map['brand'] as String).toSet().toList();
      logger.d('Loaded ${brands.length} preset brands: $brands');
      return brands;
    } catch (e) {
      logger.e('Error loading preset brands: $e');
      return [];
    }
  }

  Future<List<String>> getPresetBrandsByVehicleType(String vehicleType) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        distinct: true,
        columns: ['brand'],
        where: 'vehicle_type = ? AND is_preset = 1',
        whereArgs: [vehicleType],
        orderBy: 'brand ASC',
      );
      final brands = maps.map((map) => map['brand'] as String).toList();
      logger.d('Loaded ${brands.length} preset brands for vehicle type $vehicleType: $brands');
      return brands;
    } catch (e) {
      logger.e('Error loading preset brands for $vehicleType: $e');
      return [];
    }
  }

  Future<List<String>> getPresetModelsByBrandAndType(String brand, String vehicleType) async {
    final db = await database;
    try {
      final String trimmedVehicleType = vehicleType.trim();
      final String whereClause = 'brand = ? AND vehicle_type = ? AND is_preset = ?';
      final List<dynamic> whereArgs = [brand, trimmedVehicleType, 1];
      logger.d('Executing SQL query for models: SELECT DISTINCT model FROM cars WHERE $whereClause WITH ARGS $whereArgs');
      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        columns: ['model'],
        where: whereClause,
        whereArgs: whereArgs,
        distinct: true,
        orderBy: 'model',
      );
      final models = maps.map((map) => map['model'] as String).toSet().toList();
      logger.d('Loaded ${models.length} preset models for brand $brand and vehicle type $trimmedVehicleType: $models');
      return models;
    } catch (e) {
      logger.e('Error loading preset models: $e');
      return [];
    }
  }

  Future<List<String>> getPresetGenerations(String brand, String model, String vehicleType) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cars',
      columns: ['generation'],
      distinct: true,
      where: 'brand = ? AND model = ? AND vehicle_type = ? AND generation IS NOT NULL AND is_preset = 1',
      whereArgs: [brand, model, vehicleType],
      orderBy: 'generation',
    );
    logger.d('Loaded ${maps.length} generations for $brand $model ($vehicleType)');
    return List.generate(maps.length, (i) => maps[i]['generation'] as String);
  }

  Future<List<String>> getPresetModifications(String brand, String model, String? generation, String vehicleType) async {
    final db = await database;
    String whereClause = 'brand = ? AND model = ? AND vehicle_type = ? AND is_preset = 1 AND modification IS NOT NULL';
    List<dynamic> whereArgs = [brand, model, vehicleType];

    if (generation != null && generation != 'No Generation') {
      whereClause += ' AND generation = ?';
      whereArgs.add(generation);
    } else if (generation == 'No Generation') {
      whereClause += ' AND generation IS NULL';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'cars',
      columns: ['modification'],
      distinct: true,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'modification',
    );
    logger.d('Loaded ${maps.length} modifications for $brand $model ($generation, $vehicleType)');
    return List.generate(maps.length, (i) => maps[i]['modification'] as String);
  }

  Future<CarData?> getFullCarData(String brand, String model, String? generation, String? modification, String vehicleType) async {
    final db = await database;
    try {
      String whereClause = 'brand = ? AND model = ? AND vehicle_type = ? AND is_preset = 1';
      List<dynamic> whereArgs = [brand, model, vehicleType];

      if (generation != null && generation != 'No Generation') {
        whereClause += ' AND generation = ?';
        whereArgs.add(generation);
      } else if (generation == 'No Generation') {
        whereClause += ' AND generation IS NULL';
      }

      if (modification != null && modification != 'No Modification') {
        whereClause += ' AND modification = ?';
        whereArgs.add(modification);
      } else if (modification == 'No Modification') {
        whereClause += ' AND modification IS NULL';
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      if (maps.isNotEmpty) {
        logger.d('Full car data found: ${maps.first}');
        return CarData.fromJson(maps.first);
      }
      logger.w('No full car data found for the selection.');
      return null;
    } catch (e) {
      logger.e('Error getting full car data: $e');
      return null;
    }
  }

  Future<bool> isLicensePlateUnique(String licensePlate, [int? excludeCarId]) async {
    final db = await database;
    try {
      String where = 'license_plate = ?';
      List<dynamic> args = [licensePlate];
      if (excludeCarId != null) {
        where += ' AND id != ?';
        args.add(excludeCarId);
      }
      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        where: where,
        whereArgs: args,
      );
      final isUnique = maps.isEmpty;
      logger.d('License plate $licensePlate is unique: $isUnique');
      return isUnique;
    } catch (e) {
      logger.e('Error checking license plate uniqueness: $e');
      return false;
    }
  }

  Future<void> deleteCarByModel(String model) async {
    final db = await database;
    try {
      final cars = await db.query(
        'cars',
        where: 'model = ?',
        whereArgs: [model],
      );
      if (cars.isNotEmpty) {
        final carId = cars.first['id'] as int?;
        if (carId != null) {
          await db.delete(
            'cars',
            where: 'model = ?',
            whereArgs: [model],
          );
          await db.delete(
            'fuel_logs',
            where: 'car_id = ?',
            whereArgs: [carId],
          );
          logger.d('Deleted car with model: $model and associated fuel logs');
        } else {
          logger.e('Car ID is null for model: $model');
        }
      }
    } catch (e) {
      logger.e('Error deleting car by model: $e');
      rethrow;
    }
  }

  Future<void> insertCar(CarData car) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final carToInsert = car.copyWith(lastModified: now, isPreset: car.isPreset ?? 0);
      final insertedId = await db.insert(
        'cars',
        carToInsert.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logger.d('Inserted car with ID: $insertedId, data: ${carToInsert.toJson()}');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _syncCarToFirestore(user.uid, carToInsert.copyWith(id: insertedId));
      }
    } catch (e) {
      logger.e('Error inserting car: $e');
      rethrow;
    }
  }

  Future<List<CarData>> getCars() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('cars');
      final cars = List.generate(maps.length, (i) => CarData.fromJson(maps[i]));
      logger.d('Loaded ${cars.length} cars from database: ${cars.map((c) => c.toJson()).toList()}');
      return cars;
    } catch (e) {
      logger.e('Error loading cars: $e');
      return [];
    }
  }

  Future<List<CarData>> getUserCars() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'cars',
        where: 'is_preset = ?',
        whereArgs: [0],
      );
      final cars = maps.map((map) => CarData.fromJson(map)).toList();
      final uniqueCars = cars.fold<List<CarData>>([], (list, car) {
        final licensePlateKey = car.licensePlate ?? '';
        if (!list.any((c) => c.licensePlate == licensePlateKey)) {
          list.add(car);
        }
        return list;
      });
      logger.d('Loaded ${uniqueCars.length} user cars from database: ${uniqueCars.map((c) => c.toJson()).toList()}');
      return uniqueCars;
    } catch (e) {
      logger.e('Error loading user cars: $e');
      return [];
    }
  }

  Future<void> updateCar(CarData car) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final carWithTimestamp = car.copyWith(lastModified: now);
      await db.update(
        'cars',
        carWithTimestamp.toJson(),
        where: 'id = ?',
        whereArgs: [car.id],
      );
      logger.d('Updated car: ${carWithTimestamp.toJson()}');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _syncCarToFirestore(user.uid, carWithTimestamp);
      }
    } catch (e) {
      logger.e('Error updating car: $e');
      rethrow;
    }
  }

  Future<void> deleteCar(int id) async {
    final db = await database;
    try {
      await db.delete(
        'cars',
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'fuel_logs',
        where: 'car_id = ?',
        whereArgs: [id],
      );
      logger.d('Deleted car with id: $id');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _deleteCarFromFirestore(user.uid, id);
      }
    } catch (e) {
      logger.e('Error deleting car: $e');
      rethrow;
    }
  }

  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final carsJson = prefs.getStringList('car_history') ?? [];

    if (carsJson.isNotEmpty) {
      final db = await database;
      for (var json in carsJson) {
        try {
          final carData = jsonDecode(json) as Map<String, dynamic>;
          final car = CarData(
            brand: carData['brand']?.toString() ?? '',
            model: carData['model']?.toString() ?? '',
            licensePlate: carData['license_plate']?.toString(),
            baseCityNorm: double.tryParse(carData['base_rate']?.toString() ?? '0') ?? 0.0,
            baseHighwayNorm: double.tryParse(carData['base_rate']?.toString() ?? '0') ?? 0.0,
            lastModified: DateTime.now().millisecondsSinceEpoch,
          );
          await db.insert('cars', car.toJson(), conflictAlgorithm: ConflictAlgorithm.ignore);
          logger.d('Migrated car from SharedPreferences: $carData');
        } catch (e) {
          logger.e('Error migrating car: $e, JSON: $json');
        }
      }
      await prefs.remove('car_history');
      logger.d('Migration from SharedPreferences completed');
    } else {
      logger.d('No cars to migrate from SharedPreferences');
    }
  }

  Future<void> addPresetCars(List<CarData> cars) async {
    final db = await database;
    try {
      for (var car in cars) {
        final existingCars = await db.query(
          'cars',
          where: 'brand = ? AND model = ? AND is_preset = ?',
          whereArgs: [car.brand, car.model, 1],
        );
        if (existingCars.isEmpty) {
          await db.insert(
            'cars',
            car.toJson(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          logger.d('Added preset car: ${car.toJson()}');
        } else {
          logger.d('Skipping duplicate preset car: ${car.brand} ${car.model}');
        }
      }
      logger.d('Added ${cars.length} preset cars to the database');
    } catch (e) {
      logger.e('Error adding preset cars: $e');
      rethrow;
    }
  }

  Future<void> syncCarsWithFirestore(String uid) async {
    int retries = 3;
    while (retries > 0) {
      try {
        final db = await database;
        final prefs = await SharedPreferences.getInstance();
        final isPremium = prefs.getBool('isPremium') ?? false;
        if (!isPremium) {
          logger.d('Sync skipped: User is not premium');
          return;
        }

        final firestore = FirebaseFirestore.instance;
        final localCars = await getUserCars();
        final remoteCarsSnapshot = await firestore.collection('users').doc(uid).collection('cars').get();

        final remoteCars = remoteCarsSnapshot.docs.map((doc) {
          final data = doc.data();
          return CarData.fromJson({
            ...data,
            'id': int.parse(doc.id),
          });
        }).toList();

        for (var localCar in localCars) {
          final remoteCar = remoteCars.firstWhere(
            (rc) => rc.id == localCar.id,
            orElse: () => CarData(
              id: 0,
              brand: '',
              model: '',
              baseCityNorm: 0.0,
              baseHighwayNorm: 0.0,
            ),
          );
          if (remoteCar.id == 0 || (localCar.lastModified ?? 0) > (remoteCar.lastModified ?? 0)) {
            await _syncCarToFirestore(uid, localCar);
          } else if ((remoteCar.lastModified ?? 0) > (localCar.lastModified ?? 0)) {
            await db.update(
              'cars',
              remoteCar.toJson(),
              where: 'id = ?',
              whereArgs: [remoteCar.id],
            );
            logger.d('Updated local car from Firestore: ${remoteCar.toJson()}');
          }
        }

        for (var remoteCar in remoteCars) {
          if (!localCars.any((lc) => lc.id == remoteCar.id)) {
            await db.insert('cars', remoteCar.toJson());
            logger.d('Inserted remote car to local: ${remoteCar.toJson()}');
          }
        }

        for (var localCar in localCars) {
          if (!remoteCars.any((rc) => rc.id == localCar.id)) {
            await db.delete('cars', where: 'id = ?', whereArgs: [localCar.id]);
            logger.d('Deleted local car not in Firestore: id=${localCar.id}');
          }
        }

        logger.d('Car sync with Firestore completed');
        break; // Success, exit loop
      } catch (e) {
        retries--;
        logger.w('Retry sync: $retries left');
        if (retries == 0) throw e;
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<void> _syncCarToFirestore(String uid, CarData car) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).collection('cars').doc(car.id.toString()).set(car.toJson());
      logger.d('Synced car to Firestore: ${car.toJson()}');
    } catch (e) {
      logger.e('Error syncing car to Firestore: $e');
      throw Exception('Failed to sync car: $e');
    }
  }

  Future<void> _deleteCarFromFirestore(String uid, int id) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).collection('cars').doc(id.toString()).delete();
      logger.d('Deleted car from Firestore: id=$id');
    } catch (e) {
      logger.e('Error deleting car from Firestore: $e');
      throw Exception('Failed to delete car: $e');
    }
  }

  Future<void> _createWeatherCoefficientsTable(Database db) async {
  // 1. Создаем саму таблицу
  await db.execute('''
    CREATE TABLE weather_coefficients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      condition_type TEXT NOT NULL,
      range_min REAL NOT NULL,
      range_max REAL,
      multiplier REAL NOT NULL
    )
  ''');

  // 2. Готовим список коэффициентов для наполнения
  final List<Map<String, dynamic>> coefficients = [
    // --- Температура (в градусах Цельсия) ---
    // Сильный мороз
    {'condition_type': 'TEMPERATURE', 'range_min': -100, 'range_max': -25, 'multiplier': 1.15},
    // Мороз
    {'condition_type': 'TEMPERATURE', 'range_min': -24.9, 'range_max': -15, 'multiplier': 1.12},
    // Умеренный холод
    {'condition_type': 'TEMPERATURE', 'range_min': -14.9, 'range_max': -5, 'multiplier': 1.08},
    // Небольшой холод
    {'condition_type': 'TEMPERATURE', 'range_min': -4.9, 'range_max': 4.9, 'multiplier': 1.05},
    // Идеальные условия
    {'condition_type': 'TEMPERATURE', 'range_min': 5, 'range_max': 25, 'multiplier': 1.0},
    // Жара
    {'condition_type': 'TEMPERATURE', 'range_min': 25.1, 'range_max': 35, 'multiplier': 1.07},
    // Сильная жара
    {'condition_type': 'TEMPERATURE', 'range_min': 35.1, 'range_max': 100, 'multiplier': 1.12},

    // --- Осадки (в мм/час) ---
    // Небольшие осадки (дождь, снег)
    {'condition_type': 'PRECIPITATION', 'range_min': 0.1, 'range_max': null, 'multiplier': 1.05},
    // Сильные осадки
    {'condition_type': 'PRECIPITATION', 'range_min': 2.5, 'range_max': null, 'multiplier': 1.10},

    // --- Ветер (в км/ч) ---
    // Умеренный ветер
    {'condition_type': 'WIND', 'range_min': 20, 'range_max': null, 'multiplier': 1.04},
    // Сильный ветер
    {'condition_type': 'WIND', 'range_min': 40, 'range_max': null, 'multiplier': 1.08},
  ];

  // 3. Вставляем все коэффициенты в таблицу
  final batch = db.batch();
  for (var coeff in coefficients) {
    batch.insert('weather_coefficients', coeff);
  }
  await batch.commit(noResult: true);

  logger.d('Created and populated weather_coefficients table');
}
}