import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/initial_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onDataLoaded;

  const SplashScreen({super.key, this.onDataLoaded});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasInitialData = prefs.getBool('has_initial_data') ?? false;
    if (!hasInitialData) {
      try {
        await InitialData.addInitialCars();
        await prefs.setBool('has_initial_data', true);
        logger.d('Начальные данные успешно добавлены');
      } catch (e) {
        logger.e('Ошибка добавления начальных данных: $e');
      }
    }

    await Future.delayed(const Duration(seconds: 2));

    if (widget.onDataLoaded != null) {
      widget.onDataLoaded!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030F19) : const Color(0xFFFFE3AD),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✨ FIX: Возвращаем расширение .png и оригинальную логику
          Image.asset(
            isDark ? 'assets/launch_image_2.png' : 'assets/launch_image.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              logger.e('Ошибка загрузки сплеш-изображения: $error');
              return Center(
                child: Text(
                  l10n.logo_not_found,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF5C191B),
                    fontSize: 16,
                    fontFamily: 'Roboto',
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Lottie.asset(
                      'assets/loading_animation.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) {
                        logger.e('Ошибка загрузки анимации: $error');
                        return CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFFFFA586) : const Color(0xFFDD723C),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loading_car_database,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF5C191B),
                      fontSize: 16,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}