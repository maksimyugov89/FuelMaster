import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/constants.dart';

class AppSettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  late Locale _locale;
  late bool _isDarkMode;
  late bool _isPremium;
  late bool _isRegistered;
  late bool _onboardingCompleted;
  late String _themeMode;

  Locale get locale => _locale;
  bool get isDarkMode => _isDarkMode;
  bool get isPremium => _isPremium;
  bool get isRegistered => _isRegistered;
  bool get onboardingCompleted => _onboardingCompleted;
  String get themeMode => _themeMode;

  AppSettingsProvider(SharedPreferences prefs, Locale initialLocale, bool initialDarkMode) {
    _prefs = prefs;
    _locale = initialLocale;
    _isPremium = _prefs.getBool(AppConstants.isPremiumKey) ?? false;
    _isRegistered = _prefs.getBool(AppConstants.isRegisteredKey) ?? false;
    _onboardingCompleted = _prefs.getBool(AppConstants.onboardingCompletedKey) ?? false;
    _themeMode = _prefs.getString(AppConstants.themeModeKey) ?? 'auto';
    _updateDarkModeBasedOnThemeMode();
  }

  void _updateDarkModeBasedOnThemeMode() {
    if (_themeMode == 'auto') {
      _isDarkMode = WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    } else {
      _isDarkMode = _themeMode == 'dark';
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
    if (_isPremium == isPremium) return;
    _isPremium = isPremium;
    _prefs.setBool(AppConstants.isPremiumKey, _isPremium);
    notifyListeners();
  }

  void setRegistered(bool isRegistered) {
    if (_isRegistered == isRegistered) return;
    _isRegistered = isRegistered;
    _prefs.setBool(AppConstants.isRegisteredKey, _isRegistered);
    notifyListeners();
  }

  void setOnboardingCompleted(bool completed) {
    if (_onboardingCompleted == completed) return;
    _onboardingCompleted = completed;
    _prefs.setBool(AppConstants.onboardingCompletedKey, _onboardingCompleted);
    notifyListeners();
  }
}