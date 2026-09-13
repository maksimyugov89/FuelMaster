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
  late List<CarData> testCars;

  setUp(() {
    testCars = [
      CarData(
        id: 1,
        brand: 'Test',
        model: 'Car',
        baseCityNorm: 8.0,
        baseHighwayNorm: 6.0,
        vehicleType: 'Passenger Car',
      ),
    ];

    mockDbHelper = MockDatabaseHelper();
    when(mockDbHelper.getCars()).thenAnswer((_) async => List<CarData>.from(testCars));
    when(mockDbHelper.insertCar(any)).thenAnswer((invocation) async {
      final car = invocation.positionalArguments[0] as CarData;
      testCars.add(car.copyWith(id: testCars.length + 1));
    });
    when(mockDbHelper.updateCar(any)).thenAnswer((_) async {});
    when(mockDbHelper.deleteCar(any)).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as int;
      testCars.removeWhere((c) => c.id == id);
    });

    carProvider = CarProvider(dbHelper: mockDbHelper, autoLoad: false);
  });

  group('CarProvider Tests', () {
    test('Initial state is empty before load', () {
      expect(carProvider.cars, isEmpty);
      expect(carProvider.isLoading, false);
    });

    test('loadCars fetches cars from database', () async {
      await carProvider.loadCars();
      expect(carProvider.cars, hasLength(1));
      expect(carProvider.cars.first.brand, 'Test');
      expect(carProvider.isLoading, false);
    });

    test('addCar calls insertCar and reloads cars', () async {
      await carProvider.loadCars();
      final car = CarData(
        brand: 'New',
        model: 'Car',
        baseCityNorm: 9.0,
        baseHighwayNorm: 7.0,
        vehicleType: 'Passenger Car',
      );
      final result = await carProvider.addCar(car);
      expect(result, true);
      verify(mockDbHelper.insertCar(car)).called(1);
      expect(carProvider.cars, hasLength(2));
      expect(carProvider.cars.any((c) => c.brand == 'New'), isTrue);
    });

    test('updateCar calls updateCar and reloads cars', () async {
      await carProvider.loadCars();
      final car = carProvider.cars.first.copyWith(baseCityNorm: 8.5);
      final result = await carProvider.updateCar(car);
      expect(result, true);
      verify(mockDbHelper.updateCar(car)).called(1);
    });

    test('deleteCar calls deleteCar and reloads cars', () async {
      await carProvider.loadCars();
      final result = await carProvider.deleteCar(1);
      expect(result, true);
      verify(mockDbHelper.deleteCar(1)).called(1);
      expect(carProvider.cars, isEmpty);
    });
  });
}
