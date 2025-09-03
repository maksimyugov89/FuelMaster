import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/utils/weather_service.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/utils/logger.dart';

class WeatherDisplayWidget extends StatefulWidget {
  const WeatherDisplayWidget({super.key});

  @override
  State<WeatherDisplayWidget> createState() => _WeatherDisplayWidgetState();
}

class _WeatherDisplayWidgetState extends State<WeatherDisplayWidget> {
  late Future<Map<String, dynamic>?> _weatherFuture;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _weatherFuture = _loadWeatherForUserCity();
  }

  Future<Map<String, dynamic>?> _loadWeatherForUserCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(AppConstants.userCityKey);
      if (city == null || city.isEmpty) {
        logger.w('Город пользователя не найден в SharedPreferences.');
        return null;
      }
      logger.d('Загрузка погоды для города: $city');
      return await _weatherService.getWeatherData(city);
    } catch (e) {
      logger.e('Ошибка при загрузке погоды: $e');
      return null;
    }
  }

  Widget _buildWeatherDetail(IconData icon, String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 1.0, color: Colors.black54)],
          ),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            unit,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              shadows: [Shadow(blurRadius: 1.0, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          logger.e('Ошибка загрузки данных о погоде: ${snapshot.error}');
          return const Icon(Icons.error_outline, color: Colors.white70, size: 24);
        }

        final weatherData = snapshot.data!;
        final currentWeather = weatherData['current'];
        final location = weatherData['location'];

        final temp = (currentWeather['temp_c'] as double).round();
        final conditionIconUrl = 'https:${currentWeather['condition']['icon']}';
        final city = location['name'];
        final windKph = currentWeather['wind_kph'] as double;
        final windMs = (windKph / 3.6).round();
        final pressureMb = currentWeather['pressure_mb'] as double;
        final pressureMmHg = (pressureMb * 0.750062).round();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- НАЧАЛО ИЗМЕНЕНИЙ ---

              // --- ЛЕВЫЙ БЛОК: Иконка, температура и город ---
              Row(
                children: [
                  Image.network(
                    conditionIconUrl,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.wb_cloudy, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    // Выравниваем текст по левому краю
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(
                        '$temp°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 2.0, color: Colors.black38)],
                        ),
                      ),
                      Text(
                        city,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [Shadow(blurRadius: 2.0, color: Colors.black38)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 12), // Отступ между блоками

              // --- ПРАВЫЙ БЛОК: Скорость ветра и давление ---
              Column(
                // Выравниваем иконки и текст по правому краю
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWeatherDetail(Icons.air, windMs.toString(), 'м/с'),
                  const SizedBox(height: 4),
                  _buildWeatherDetail(Icons.arrow_downward, pressureMmHg.toString(), 'мм'),
                ],
              ),
              
              // --- КОНЕЦ ИЗМЕНЕНИЙ ---
            ],
          ),
        );
      },
    );
  }
}

