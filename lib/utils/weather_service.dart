import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/database_helper.dart';

class WeatherService {
  static final String _apiKey = dotenv.env['WEATHER_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.weatherapi.com/v1/current.json';
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> getWeatherData(String city) async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiUrl?key=$_apiKey&q=$city&aqi=no'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.d('Weather data for $city: $data');
        await _cacheWeatherData(city, data);
        return data;
      } else {
        logger.e('WeatherAPI error: Status ${response.statusCode}, ${response.body}');
        return await _getCachedWeatherData(city);
      }
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

    final temp = weatherData['current']['temp_c'] as double;
    final precip = weatherData['current']['precip_mm'] as double;
    final wind = weatherData['current']['wind_kph'] as double;

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
      multiplier *= tempResult.first['multiplier'] as double;
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
        multiplier *= precipResult.first['multiplier'] as double;
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
        multiplier *= windResult.first['multiplier'] as double;
        logger.d('Applied wind multiplier: ${windResult.first['multiplier']} for wind: $wind kph');
      }
    }

    return multiplier;
  }
}