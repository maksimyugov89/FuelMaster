import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/services/location_service.dart'; // <-- ИМПОРТ СЕРВИСА

class AppInitializer {
  static Future<Map<String, dynamic>> initialize() async {
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
    // B-6 аудита: геолокация запускалась на самом старте, до онбординга —
    // у нового пользователя диалог разрешения висел поверх сплэша, а при отказе
    // город не определялся вовсе. Спрашиваем геопозицию только у уже
    // зарегистрированных (у новых это делает экран регистрации), а сам запрос
    // ограничен по времени, чтобы не блокировать запуск приложения.
    final isRegistered = prefs.getBool(AppConstants.isRegisteredKey) ?? false;
    if (isRegistered && prefs.getString(AppConstants.userCityKey) == null) {
      logger.d('Город пользователя не найден, попытка определения...');
      final locationService = LocationService();
      final city = await locationService.getCurrentCity().timeout(
            const Duration(seconds: 15),
            onTimeout: () => null,
          );
      if (city != null) {
        await prefs.setString(AppConstants.userCityKey, city);
        logger.d('Город ($city) успешно сохранен в SharedPreferences.');
      } else {
        logger.w('Не удалось определить и сохранить город пользователя.');
      }
    } else if (!isRegistered) {
      logger.d('Геолокация на старте пропущена: пользователь ещё не зарегистрирован (B-6)');
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
      // ВАЖНО: раньше здесь писалось isPremium = false, и пользователь,
      // купивший премиум, терял его навсегда, если магазин в этот момент
      // недоступен (офлайн, нет Google Play). Статус меняет только
      // PremiumService по подтверждению магазина.
      logger.w('InAppPurchase недоступен — покупки внутри приложения отключены');
    }

    final hasMigrated = prefs.getBool(AppConstants.hasMigratedKey) ?? false;
    if (!hasMigrated) {
      try {
        await DatabaseHelper.instance.migrateFromSharedPreferences();
        await prefs.setBool(AppConstants.hasMigratedKey, true);
        logger.d('Миграция автомобилей из SharedPreferences выполнена');
      } catch (e) {
        logger.e('Ошибка миграции автомобилей: $e');
      }
    }

    final historyMigrated = prefs.getBool(AppConstants.historyPrefsMigratedKey) ?? false;
    if (!historyMigrated) {
      try {
        await HistoryManager.migrateFromSharedPreferences();
        await prefs.setBool(AppConstants.historyPrefsMigratedKey, true);
        logger.d('Миграция истории из SharedPreferences выполнена');
      } catch (e) {
        logger.e('Ошибка миграции истории: $e');
      }
    }

    return {
      'sharedPreferences': prefs,
      'isDarkMode': isDarkMode,
      'initialLocale': Locale(language),
    };
  }
}
