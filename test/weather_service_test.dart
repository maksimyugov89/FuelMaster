import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuelmaster/utils/weather_service.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'weather_service_test.mocks.dart';

@GenerateMocks([http.Client, Database])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Инициализация sqflite_common_ffi для тестирования
  if (identical(1, 1.0)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  group('WeatherService Tests', () {
    late WeatherService weatherService;
    late MockClient mockHttpClient;
    late MockDatabase mockDatabase;

    setUp(() {
      mockHttpClient = MockClient();
      mockDatabase = MockDatabase();
      weatherService = WeatherService(client: mockHttpClient);

      // Мокируем геттер database
      when(DatabaseHelper.instance.database).thenAnswer((_) async => mockDatabase);

      // Мокируем HTTP-запрос
      when(mockHttpClient.get(
        Uri.parse('https://api.geoapify.com/v1/weather?city=Москва&apiKey=YOUR_API_KEY'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            '{"location": {"lat": 55.75, "lon": 37.62, "tz_id": "Europe/Moscow"}, "current": {"temp_c": -8, "precip_mm": 5.2, "wind_kph": 15}}',
            200,
          ));

      // Мокируем запросы к weather_coefficients
      when(mockDatabase.query(
        'weather_coefficients',
        where: 'condition_type = ? AND range_min <= ? AND range_max >= ?',
        whereArgs: ['TEMPERATURE', -8.0, -8.0],
        limit: 1,
      )).thenAnswer((_) async => [
            {
              'condition_type': 'TEMPERATURE',
              'range_min': -15,
              'range_max': -5,
              'multiplier': 1.15,
              'description': 'Moderate frost'
            }
          ]);

      when(mockDatabase.query(
        'weather_coefficients',
        where: 'condition_type = ? AND range_min <= ?',
        whereArgs: ['PRECIPITATION', 5.2],
        orderBy: 'range_min DESC',
        limit: 1,
      )).thenAnswer((_) async => [
            {
              'condition_type': 'PRECIPITATION',
              'range_min': 5,
              'range_max': 20,
              'multiplier': 1.10,
              'description': 'Heavy rain/snow'
            }
          ]);

      when(mockDatabase.query(
        'weather_coefficients',
        where: 'condition_type = ? AND range_min <= ?',
        whereArgs: ['WIND', 15.0],
        orderBy: 'range_min DESC',
        limit: 1,
      )).thenAnswer((_) async => [
            {
              'condition_type': 'WIND',
              'range_min': 10,
              'range_max': 20,
              'multiplier': 1.05,
              'description': 'Strong wind'
            }
          ]);

      // Мокируем insert для locations
      when(mockDatabase.insert(
        'locations',
        any,
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).thenAnswer((invocation) async {
        final map = invocation.positionalArguments[1] as Map<String, dynamic>;
        logger.d('Mock insert called with map: $map');
        expect(map['city'], 'Москва');
        expect(map['latitude'], 55.75);
        expect(map['longitude'], 37.62);
        expect(map['timezone'], 'Europe/Moscow');
        expect(map.containsKey('last_weather_update'), true);
        expect(map.containsKey('weather_data'), true);
        return 1;
      });
    });

    test('Get weather multiplier for city', () async {
      final multiplier = await weatherService.getWeatherMultiplier('Москва');
      expect(multiplier, closeTo(1.15 * 1.10 * 1.05, 0.01)); // Ожидаем произведение коэффициентов
      verify(mockHttpClient.get(
        Uri.parse('https://api.geoapify.com/v1/weather?city=Москва&apiKey=YOUR_API_KEY'),
        headers: anyNamed('headers'),
      )).called(1);
    });
  });
}