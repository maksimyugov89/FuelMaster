import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/services/premium_service.dart';

class AppSettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  late Locale _locale;
  late bool _isDarkMode;
  late bool _isRegistered;
  late bool _onboardingCompleted;
  late String _themeMode;
  bool _isEmailVerified = false;

  Locale get locale => _locale;
  bool get isDarkMode => _isDarkMode;
  // Единственный источник правды — PremiumService (prefs + магазин).
  bool get isPremium => PremiumService.instance.isPremium;
  bool get isRegistered => _isRegistered;
  /// Подтверждён ли e-mail (F-2). Значение приходит из FirebaseAuth и в prefs
  /// не сохраняется: это серверный факт, а не пользовательская настройка.
  bool get isEmailVerified => _isEmailVerified;
  bool get onboardingCompleted => _onboardingCompleted;
  String get themeMode => _themeMode;

  AppSettingsProvider(SharedPreferences prefs, Locale initialLocale, bool initialDarkMode) {
    _prefs = prefs;
    _locale = initialLocale;
    _isRegistered = _prefs.getBool(AppConstants.isRegisteredKey) ?? false;
    _onboardingCompleted = _prefs.getBool(AppConstants.onboardingCompletedKey) ?? false;
    _themeMode = _prefs.getString(AppConstants.themeModeKey) ?? 'auto';
    _updateDarkModeBasedOnThemeMode(initialDarkMode: initialDarkMode);
    // Обновляем подписчиков, когда премиум приходит из магазина.
    PremiumService.instance.addListener(notifyListeners);
  }

  void _updateDarkModeBasedOnThemeMode({bool? initialDarkMode}) {
    if (_themeMode == 'auto') {
      _isDarkMode =
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else if (_themeMode == 'dark') {
      _isDarkMode = true;
    } else if (_themeMode == 'light') {
      _isDarkMode = false;
    } else if (initialDarkMode != null) {
      _isDarkMode = initialDarkMode;
    } else {
      _isDarkMode = false;
    }
  }

  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    _prefs.setString(AppConstants.languageKey, newLocale.languageCode);
    logger.d('Язык изменён на: ${newLocale.languageCode}');
    notifyListeners();
  }

  void setTheme(String mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs.setString(AppConstants.themeModeKey, _themeMode);
    _updateDarkModeBasedOnThemeMode();
    notifyListeners();
    logger.d('Theme changed to $mode');
  }

  void setPremium(bool isPremium) {
    PremiumService.instance.setPremium(isPremium);
  }

  void setRegistered(bool isRegistered) {
    if (_isRegistered == isRegistered) return;
    _isRegistered = isRegistered;
    _prefs.setBool(AppConstants.isRegisteredKey, _isRegistered);
    notifyListeners();
  }

  void setEmailVerified(bool verified) {
    if (_isEmailVerified == verified) return;
    _isEmailVerified = verified;
    notifyListeners();
  }

  void setOnboardingCompleted(bool completed) {
    if (_onboardingCompleted == completed) return;
    _onboardingCompleted = completed;
    _prefs.setBool(AppConstants.onboardingCompletedKey, _onboardingCompleted);
    notifyListeners();
  }
}