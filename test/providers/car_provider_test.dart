import 'package:flutter_test/flutter_test.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'car_provider_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  late CarProvider carProvider;
  late MockDatabaseHelper mockDbHelper;

  setUp(() {
    mockDbHelper = MockDatabaseHelper();
    carProvider = CarProvider(dbHelper: mockDbHelper);

    // Моки для методов
    when(mockDbHelper.getCars()).thenAnswer((_) async => [
          CarData(
            id: 1,
            brand: 'Test',
            model: 'Car',
            baseCityNorm: 8.0,
            baseHighwayNorm: 6.0,
            vehicleType: 'Passenger Car',
          )
        ]);
    when(mockDbHelper.insertCar(any)).thenAnswer((_) async => true);
    when(mockDbHelper.updateCar(any)).thenAnswer((_) async => true);
    when(mockDbHelper.deleteCar(any)).thenAnswer((_) async => true);
  });

  group('CarProvider Tests', () {
    test('Initial state is correct', () {
      expect(carProvider.cars, isNotEmpty);
      expect(carProvider.isLoading, false);
    });

    test('loadCars fetches cars from database', () async {
      await carProvider.loadCars();
      expect(carProvider.cars, isNotEmpty);
      expect(carProvider.cars.first.brand, 'Test');
    });

    test('addCar calls insertCar and reloads cars', () async {
      final car = CarData(
        brand: 'Test',
        model: 'Car',
        baseCityNorm: 8.0,
        baseHighwayNorm: 6.0,
        vehicleType: 'Passenger Car',
      );
      final result = await carProvider.addCar(car);
      expect(result, true);
      verify(mockDbHelper.insertCar(car)).called(1);
      expect(carProvider.cars, contains(car));
    });

    test('updateCar calls updateCar and reloads cars', () async {
      final car = CarData(
        id: 1,
        brand: 'Test',
        model: 'Car',
        baseCityNorm: 8.0,
        baseHighwayNorm: 6.0,
        vehicleType: 'Passenger Car',
      );
      final result = await carProvider.updateCar(car);
      expect(result, true);
      verify(mockDbHelper.updateCar(car)).called(1);
      expect(carProvider.cars, contains(car));
    });

    test('deleteCar calls deleteCar and reloads cars', () async {
      final result = await carProvider.deleteCar(1);
      expect(result, true);
      verify(mockDbHelper.deleteCar(1)).called(1);
      expect(carProvider.cars, isEmpty);
    });
  });
}