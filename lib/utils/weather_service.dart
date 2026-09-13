import 'dart:async';
import 'dart:convert';
import 'package:fuelmaster/utils/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/database_helper.dart';

class WeatherService {
  static final String _apiKey = EnvConfig.get('WEATHER_API_KEY');
  static const String _apiUrl = 'https://api.weatherapi.com/v1/current.json';

  /// B-4 аудита: без таймаута «залипшее» соединение держало расчёт топлива
  /// в вечном ожидании.
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> getWeatherData(String city) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_apiUrl?key=$_apiKey&q=$city&aqi=no'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _cacheWeatherData(city, data);
        return data;
      } else {
        logger.e('WeatherAPI error: Status ${response.statusCode}');
        return await _getCachedWeatherData(city);
      }
    } on TimeoutException {
      logger.e('WeatherAPI: таймаут ${_timeout.inSeconds} с для $city');
      return await _getCachedWeatherData(city);
    } catch (e) {
      logger.e('Error fetching weather data: $e');
      return await _getCachedWeatherData(city);
    }
  }

  Future<void> _cacheWeatherData(String city, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'locations',
      {
        'city': city,
        'latitude': data['location']['lat'],
        'longitude': data['location']['lon'],
        'timezone': data['location']['tz_id'],
        'last_weather_update': now,
        'weather_data': jsonEncode(data['current']),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    logger.d('Cached weather data for $city at $now');
  }

  Future<Map<String, dynamic>?> _getCachedWeatherData(String city) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'locations',
      where: 'city = ? AND last_weather_update > ?',
      whereArgs: [city, DateTime.now().subtract(Duration(hours: 1)).toIso8601String()],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final weatherData = result.first['weather_data'] as String?;
      if (weatherData != null) {
        logger.d('Using cached weather data for $city');
        return {'current': jsonDecode(weatherData)};
      }
    }
    return null;
  }

  Future<double> getWeatherMultiplier(String city) async {
    final weatherData = await getWeatherData(city);
    if (weatherData == null) {
      logger.w('No weather data available for $city, using default multiplier');
      return 1.0;
    }

    final current = weatherData['current'];
    if (current is! Map) {
      logger.w('Некорректные данные о погоде для $city — множитель 1.0');
      return 1.0;
    }

    // B-5 аудита: WeatherAPI отдаёт целые значения как int (20, а не 20.0),
    // а касты `as double` роняли расчёт топлива с TypeError.
    final temp = parseNumeric(current['temp_c'], 0);
    final precip = parseNumeric(current['precip_mm'], 0);
    final wind = parseNumeric(current['wind_kph'], 0);

    double multiplier = 1.0;
    final db = await DatabaseHelper.instance.database;

    // Температурный коэффициент
    final tempResult = await db.query(
      'weather_coefficients',
      where: 'condition_type = ? AND range_min <= ? AND range_max >= ?',
      whereArgs: ['TEMPERATURE', temp, temp],
      limit: 1,
    );
    if (tempResult.isNotEmpty) {
      multiplier *= parseNumeric(tempResult.first['multiplier']);
      logger.d('Applied temperature multiplier: ${tempResult.first['multiplier']} for temp: $temp°C');
    }

    // Коэффициент осадков
    if (precip > 0) {
      final precipResult = await db.query(
        'weather_coefficients',
        where: 'condition_type = ? AND range_min <= ?',
        whereArgs: ['PRECIPITATION', precip],
        orderBy: 'range_min DESC',
        limit: 1,
      );
      if (precipResult.isNotEmpty) {
        multiplier *= parseNumeric(precipResult.first['multiplier']);
        logger.d('Applied precipitation multiplier: ${precipResult.first['multiplier']} for precip: $precip mm');
      }
    }

    // Коэффициент ветра
    if (wind > 0) {
      final windResult = await db.query(
        'weather_coefficients',
        where: 'condition_type = ? AND range_min <= ?',
        whereArgs: ['WIND', wind],
        orderBy: 'range_min DESC',
        limit: 1,
      );
      if (windResult.isNotEmpty) {
        multiplier *= parseNumeric(windResult.first['multiplier']);
        logger.d('Applied wind multiplier: ${windResult.first['multiplier']} for wind: $wind kph');
      }
    }

    return multiplier;
  }

  /// Безопасное приведение значения из JSON/SQLite к double.
  ///
  /// Числа из ответа API и из SQLite могут быть int — прямой каст `as double`
  /// на них падает с TypeError (см. B-5 аудита).
  static double parseNumeric(dynamic value, [double fallback = 1.0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
