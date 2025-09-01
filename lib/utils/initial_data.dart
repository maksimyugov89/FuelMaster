import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:sqflite/sqflite.dart';

class InitialData {
  static Future<void> addInitialCars() async {
    final db = await DatabaseHelper.instance.database;
    try {
      String csvString = await rootBundle.loadString('assets/cars.csv');
      await _addCarsFromCsv(csvString, db);
      logger.d('Successfully added initial cars to the database');
    } catch (e) {
      logger.e('Error adding initial cars: $e');
    }
  }

  static Future<List<String>> getCsvBrands() async {
    try {
      final String csvString = await rootBundle.loadString('assets/cars.csv');
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      final brands =
          rows.skip(1).map((row) => row[0].toString().trim()).toSet().toList();
      logger.d('Loaded brands from CSV: $brands');
      return brands;
    } catch (e) {
      logger.e('Error loading brands from cars.csv: $e');
      return [];
    }
  }

  static Future<void> addCarsFromExternalCsv(String csvContent) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await _addCarsFromCsv(csvContent, db);
      logger.d('Successfully added cars from external CSV');
    } catch (e) {
      logger.e('Error adding cars from external CSV: $e');
    }
  }

  static Future<void> _addCarsFromCsv(String csvString, Database db) async {
    final List<List<dynamic>> rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(csvString);
    final List<CarData> predefinedCars = [];
    if (rows.isEmpty || rows.first.isEmpty) {
      logger.e('CSV file is empty or invalid');
      return;
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    logger.d('CSV Headers: $headers');
    final brandIndex = headers.indexOf('brand');
    final modelIndex = headers.indexOf('model');
    final modificationIndex = headers.indexOf('modification');
    final cylindersIndex = headers.indexOf('cylinders');
    // В вашем CSV файле powerHp, а не power_hp
    final powerHpIndex = headers.indexOf('powerHp');
    // В вашем CSV файле engineVolume, а не engine_volume
    final engineVolumeIndex = headers.indexOf('engineVolume');
    // В вашем CSV файле transmissionType, а не transmission_type
    final transmissionTypeIndex = headers.indexOf('transmissionType');
    // В вашем CSV файле transmissionSpeeds, а не transmission_speeds
    final transmissionSpeedsIndex = headers.indexOf('transmissionSpeeds');
    // В вашем CSV файле baseCityNorm, а не base_rate_city
    final baseCityNormIndex = headers.indexOf('baseCityNorm');
    // В вашем CSV файле baseHighwayNorm, а не base_rate_highway
    final baseHighwayNormIndex = headers.indexOf('baseHighwayNorm');
    // В вашем CSV файле fuelType, а не fuel_type
    final fuelTypeIndex = headers.indexOf('fuelType');
    // --- ИСПРАВЛЕНО ---
    // Название столбца приведено в соответствие с вашим CSV-файлом (было 'vehicle_type')
    final vehicleTypeIndex = headers.indexOf('vehicleType');
    // --- КОНЕЦ ИСПРАВЛЕНИЯ ---
    final passengerCapacityIndex = headers.indexOf('passenger_capacity');
    final heaterFuelConsumptionIndex = headers.indexOf('heater_fuel_consumption');
    final fuelConsumptionPerTonKmIndex =
        headers.indexOf('fuel_consumption_per_ton_km');
    final trailerWeightIndex = headers.indexOf('trailer_weight');

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      // Пропускаем строки с недостаточным количеством колонок
      if (row.length < headers.length) {
        logger.w(
            'Skipping invalid row $i: expected ${headers.length} fields, got ${row.length}. Data: $row');
        continue;
      }

      try {
        // Преобразуем все элементы строки в строки, чтобы избежать ошибок с null
        final rowData = row.map((e) => e?.toString() ?? '').toList();

        String vehicleType = 'Passenger Car'; // Устанавливаем значение по умолчанию
        // Проверяем, есть ли колонка vehicleType и есть ли в ней значение
        if (vehicleTypeIndex != -1 &&
            rowData.length > vehicleTypeIndex &&
            rowData[vehicleTypeIndex].isNotEmpty) {
          vehicleType = rowData[vehicleTypeIndex].trim();
        }

        // Логируем, какой тип мы определили для строки
        logger.i('Row $i: Parsed vehicleType: "$vehicleType"');

        final brand = (brandIndex != -1 &&
                rowData.length > brandIndex &&
                rowData[brandIndex].isNotEmpty)
            ? rowData[brandIndex].trim()
            : '';
        final model = (modelIndex != -1 &&
                rowData.length > modelIndex &&
                rowData[modelIndex].isNotEmpty)
            ? rowData[modelIndex].replaceAll('"', '').trim()
            : '';

        // Пропускаем строку, если нет бренда или модели
        if (brand.isEmpty || model.isEmpty) {
          logger.w('Skipping row $i due to empty brand or model.');
          continue;
        }

        // Логируем, какую машину мы обрабатываем
        logger.i(
            'Row $i: Processing "$brand $model" as vehicle type "$vehicleType"');

        final modification = (modificationIndex != -1 &&
                rowData.length > modificationIndex &&
                rowData[modificationIndex].isNotEmpty)
            ? rowData[modificationIndex].trim()
            : null;
        final cylinders = (cylindersIndex != -1 &&
                rowData.length > cylindersIndex &&
                rowData[cylindersIndex].isNotEmpty)
            ? rowData[cylindersIndex].trim()
            : null;
        final powerHp = (powerHpIndex != -1 &&
                rowData.length > powerHpIndex &&
                rowData[powerHpIndex].isNotEmpty)
            ? double.tryParse(rowData[powerHpIndex])
            : null;
        final engineVolume = (engineVolumeIndex != -1 &&
                rowData.length > engineVolumeIndex &&
                rowData[engineVolumeIndex].isNotEmpty)
            ? double.tryParse(rowData[engineVolumeIndex])
            : null;
        final transmissionType = (transmissionTypeIndex != -1 &&
                rowData.length > transmissionTypeIndex &&
                rowData[transmissionTypeIndex].isNotEmpty)
            ? rowData[transmissionTypeIndex].trim()
            : null;
        final transmissionSpeeds = (transmissionSpeedsIndex != -1 &&
                rowData.length > transmissionSpeedsIndex &&
                rowData[transmissionSpeedsIndex].isNotEmpty)
            ? int.tryParse(rowData[transmissionSpeedsIndex])
            : null;

        // Специфические поля в зависимости от vehicleType
        double baseCityNorm = 0.0;
        double baseHighwayNorm = 0.0;
        double? baseCombinedNorm;
        String? fuelType;
        int? yearFrom = null;
        int? yearTo = null;
        int? passengerCapacity;
        double? heaterFuelConsumption;
        double? fuelConsumptionPerTonKm;
        double? trailerWeight;

        // Общие нормы для всех типов транспортных средств, где они применимы
        if (baseCityNormIndex != -1 &&
            row.length > baseCityNormIndex &&
            row[baseCityNormIndex] != null) {
          baseCityNorm =
              double.tryParse(row[baseCityNormIndex].toString()) ?? 0.0;
        }
        if (baseHighwayNormIndex != -1 &&
            row.length > baseHighwayNormIndex &&
            row[baseHighwayNormIndex] != null) {
          baseHighwayNorm =
              double.tryParse(row[baseHighwayNormIndex].toString()) ?? 0.0;
        }

        // Расчет baseCombinedNorm как среднего, если обе нормы существуют
        if (baseCityNorm > 0.0 && baseHighwayNorm > 0.0) {
          baseCombinedNorm = (baseCityNorm + baseHighwayNorm) / 2.0;
        }

        // Специфические поля в зависимости от vehicleType
        if (vehicleType == 'Bus') {
          heaterFuelConsumption = (heaterFuelConsumptionIndex != -1 &&
                  row.length > heaterFuelConsumptionIndex &&
                  row[heaterFuelConsumptionIndex] != null)
              ? double.tryParse(
                  row[heaterFuelConsumptionIndex].toString().trim())
              : null;
          fuelType = (fuelTypeIndex != -1 &&
                  row.length > fuelTypeIndex &&
                  row[fuelTypeIndex] != null)
              ? row[fuelTypeIndex]?.toString().trim()
              : null;
          passengerCapacity = (passengerCapacityIndex != -1 &&
                  row.length > passengerCapacityIndex &&
                  row[passengerCapacityIndex] != null)
              ? int.tryParse(row[passengerCapacityIndex].toString().trim())
              : null;
        } else if (vehicleType == 'Truck') {
          fuelConsumptionPerTonKm = (fuelConsumptionPerTonKmIndex != -1 &&
                  row.length > fuelConsumptionPerTonKmIndex &&
                  row[fuelConsumptionPerTonKmIndex] != null)
              ? double.tryParse(
                  row[fuelConsumptionPerTonKmIndex].toString().trim())
              : null;
          trailerWeight = (trailerWeightIndex != -1 &&
                  row.length > trailerWeightIndex &&
                  row[trailerWeightIndex] != null)
              ? double.tryParse(row[trailerWeightIndex].toString().trim())
              : null;
          fuelType = (fuelTypeIndex != -1 &&
                  row.length > fuelTypeIndex &&
                  row[fuelTypeIndex] != null)
              ? row[fuelTypeIndex]?.toString().trim()
              : null;
          heaterFuelConsumption = (heaterFuelConsumptionIndex != -1 &&
                  row.length > heaterFuelConsumptionIndex &&
                  row[heaterFuelConsumptionIndex] != null)
              ? double.tryParse(
                  row[heaterFuelConsumptionIndex].toString().trim())
              : null;
          passengerCapacity = (passengerCapacityIndex != -1 &&
                  row.length > passengerCapacityIndex &&
                  row[passengerCapacityIndex] != null)
              ? int.tryParse(row[passengerCapacityIndex].toString().trim())
              : null;
        } else {
          fuelType = (fuelTypeIndex != -1 &&
                  row.length > fuelTypeIndex &&
                  row[fuelTypeIndex] != null)
              ? row[fuelTypeIndex]?.toString().trim()
              : null;
        }

        predefinedCars.add(CarData(
          brand: brand,
          model: model,
          modification: modification,
          cylinders: cylinders,
          powerHp: powerHp,
          engineVolume: engineVolume,
          transmissionType: transmissionType,
          transmissionSpeeds: transmissionSpeeds,
          baseCityNorm: baseCityNorm,
          baseHighwayNorm: baseHighwayNorm,
          baseCombinedNorm: baseCombinedNorm,
          fuelType: fuelType,
          vehicleType: vehicleType,
          yearFrom: yearFrom,
          yearTo: yearTo,
          isPreset: 1,
          passengerCapacity: passengerCapacity,
          heaterFuelConsumption: heaterFuelConsumption,
          fuelConsumptionPerTonKm: fuelConsumptionPerTonKm,
          trailerWeight: trailerWeight,
        ));
      } catch (e) {
        logger.e('Ошибка парсинга строки CSV $i: $e. Data: $row');
        continue;
      }
    }

    // Вставка данных в базу
    final batch = db.batch();
    for (var car in predefinedCars) {
      batch.insert(
        'cars',
        car.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    logger.d('Batch inserted ${predefinedCars.length} cars into the database');
  }
}

class CsvParseException implements Exception {
  final String message;
  CsvParseException(this.message);
  @override
  String toString() => 'CsvParseException: $message';
}

class FileReadException implements Exception {
  final String message;
  FileReadException(this.message);
  @override
  String toString() => 'FileReadException: $message';
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => 'DatabaseException: $message';
}