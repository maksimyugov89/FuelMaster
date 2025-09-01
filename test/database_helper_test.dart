import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'database_helper_test.mocks.dart';

// Генерация моков с помощью mockito
@GenerateMocks([Database])
void main() {
  // Инициализация sqflite_common_ffi для тестирования
  if (identical(1, 1.0)) {
    // Для настольных платформ
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  group('DatabaseHelper Tests', () {
    late DatabaseHelper databaseHelper;
    late MockDatabase mockDatabase;

    setUp(() async {
      mockDatabase = MockDatabase();
      // Мокируем геттер database
      when(DatabaseHelper.instance.database).thenAnswer((_) async => mockDatabase);
      databaseHelper = DatabaseHelper.instance;

      // Моки для методов
      when(mockDatabase.insert(any, any, conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .thenAnswer((_) async => 1);
      when(mockDatabase.update(any, any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);
      when(mockDatabase.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);
      when(mockDatabase.query(any, columns: anyNamed('columns'), where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'brand': 'Toyota',
                  'model': 'Camry XV70',
                  'license_plate': null,
                  'generation': null,
                  'modification': null,
                  'year_from': null,
                  'year_to': null,
                  'engine_volume': 0.0,
                  'power_hp': 0.0,
                  'power_kw': 0.0,
                  'fuel_type': null,
                  'transmission_type': null,
                  'transmission_speeds': 0,
                  'base_rate_city': 8.4,
                  'base_rate_highway': 5.7,
                  'base_rate_combined': null,
                  'vehicle_type': 'Passenger Car',
                  'cylinders': null,
                  'is_preset': 0,
                  'passenger_capacity': null,
                  'heater_fuel_consumption': null,
                  'fuel_consumption_per_ton_km': null,
                  'trailer_weight': null,
                  'fuel_consumption_per_load': null,
                  'load_capacity': null,
                  'battery_capacity_kwh': null,
                  'last_modified': null
                }
              ]);
    });

    test('Insert car', () async {
      final car = CarData(
        brand: 'Toyota',
        model: 'Camry XV70',
        baseCityNorm: 8.4,
        baseHighwayNorm: 5.7,
        vehicleType: 'Passenger Car',
      );

      await databaseHelper.insertCar(car); // Убрано expect, так как метод возвращает void
      verify(mockDatabase.insert(
        'cars',
        car.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).called(1);
    });

    test('Get cars', () async {
      final cars = await databaseHelper.getUserCars();
      expect(cars.length, 1);
      expect(cars.first.brand, 'Toyota');
      expect(cars.first.model, 'Camry XV70');
      expect(cars.first.baseCityNorm, 8.4);
      expect(cars.first.baseHighwayNorm, 5.7);
      verify(mockDatabase.query('cars', where: 'is_preset = ?', whereArgs: [0])).called(1);
    });

    test('Update car', () async {
      final car = CarData(
        id: 1,
        brand: 'Toyota',
        model: 'Camry XV70',
        baseCityNorm: 8.5,
        baseHighwayNorm: 5.8,
        vehicleType: 'Passenger Car',
      );

      await databaseHelper.updateCar(car); // Убрано expect, так как метод возвращает void
      verify(mockDatabase.update(
        'cars',
        car.toJson(),
        where: 'id = ?',
        whereArgs: [car.id],
      )).called(1);
    });

    test('Delete car', () async {
      const id = 1;
      await databaseHelper.deleteCar(id); // Убрано expect, так как метод возвращает void
      verify(mockDatabase.delete(
        'cars',
        where: 'id = ?',
        whereArgs: [id],
      )).called(1);
      verify(mockDatabase.delete(
        'fuel_logs',
        where: 'car_id = ?',
        whereArgs: [id],
      )).called(1);
    });
  });
}