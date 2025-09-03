import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/firebase_options.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/services/location_service.dart'; // <-- ИМПОРТ СЕРВИСА

class AppInitializer {
  static Future<Map<String, dynamic>> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      logger.d('Firebase успешно инициализирован');
    } catch (e) {
      logger.e('Ошибка инициализации Firebase: $e');
    }

    try {
      await AdManager.initialize();
      logger.d('AdManager успешно инициализирован');
    } catch (e) {
      logger.e('Ошибка инициализации AdManager: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(AppConstants.isDarkModeKey) ?? false;

    // --- НАЧАЛО ИЗМЕНЕНИЙ: ОПРЕДЕЛЕНИЕ ГОРОДА ---
    // Проверяем, был ли город сохранен ранее
    if (prefs.getString(AppConstants.userCityKey) == null) {
      logger.d('Город пользователя не найден, попытка определения...');
      // Если нет, вызываем наш новый сервис
      final locationService = LocationService();
      final city = await locationService.getCurrentCity();
      if (city != null) {
        // Если город успешно определен, сохраняем его
        await prefs.setString(AppConstants.userCityKey, city);
        logger.d('Город ($city) успешно сохранен в SharedPreferences.');
      } else {
        logger.w('Не удалось определить и сохранить город пользователя.');
      }
    } else {
      logger.d('Используется ранее сохраненный город: ${prefs.getString(AppConstants.userCityKey)}');
    }
    // --- КОНЕЦ ИЗМЕНЕНИЙ ---

    String language = prefs.getString(AppConstants.languageKey) ?? 'en';
    if (prefs.getString(AppConstants.languageKey) == null) {
      try {
        final systemLocale = Platform.localeName;
        final sysLang = systemLocale.length >= 2 ? systemLocale.substring(0, 2) : 'en';
        final sysCountry = systemLocale.length >= 5 ? systemLocale.substring(3, 5).toLowerCase() : '';
        final russianCountries = ['ru', 'by', 'kz', 'ua', 'lv', 'lt', 'ee'];
        language = russianCountries.contains(sysCountry) || sysLang == 'ru' ? 'ru' : 'en';
        await prefs.setString(AppConstants.languageKey, language);
      } catch (e) {
        logger.e('Ошибка определения системной локали: $e, используется default en');
        language = 'en';
        await prefs.setString(AppConstants.languageKey, language);
      }
    }

    final InAppPurchase iap = InAppPurchase.instance;
    final isIapAvailable = await iap.isAvailable();
    if (!isIapAvailable) {
      logger.w('InAppPurchase недоступен');
    }

    final hasMigrated = prefs.getBool(AppConstants.hasMigratedKey) ?? false;
    if (!hasMigrated) {
      try {
        await DatabaseHelper.instance.migrateFromSharedPreferences();
        await prefs.setBool(AppConstants.hasMigratedKey, true);
        logger.d('Миграция данных успешно выполнена');
      } catch (e) {
        logger.e('Ошибка миграции данных: $e');
      }
    }

    return {
      'sharedPreferences': prefs,
      'isDarkMode': isDarkMode,
      'initialLocale': Locale(language),
    };
  }
}
