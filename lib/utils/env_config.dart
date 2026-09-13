import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Централизованный доступ к секретам.
///
/// Порядок приоритета:
/// 1. `--dart-define` / `--dart-define-from-file=env.defines.json`
/// 2. `.env` через flutter_dotenv (из assets — все режимы, или файловой системы — debug)
class EnvConfig {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Сначала пробуем загрузить из assets (работает во всех режимах)
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (_) {
      // Если assets не сработали (старая версия flutter_dotenv), пробуем файловую систему
      if (kDebugMode) {
        try {
          await dotenv.load(fileName: '.env', isOptional: true);
        } catch (_) {}
      }
    }

    _initialized = true;
  }

  static String get(String key, {String defaultValue = ''}) {
    const empty = '';
    // dart-define (compile-time) — работает в release/profile/debug c флагом
    final fromDefine = String.fromEnvironment(key, defaultValue: empty);
    if (fromDefine.isNotEmpty) return fromDefine;

    // .env через flutter_dotenv (загружен из assets)
    if (_initialized) {
      final fromDotenv = dotenv.env[key];
      if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    }

    return defaultValue;
  }

  static String? getOptional(String key) {
    final value = get(key);
    return value.isEmpty ? null : value;
  }

  static String require(String key) {
    final value = get(key);
    if (value.isEmpty) {
      throw StateError(
        'Отсутствует обязательная переменная "$key". '
        'Задайте её через --dart-define-from-file=env.defines.json '
        'или добавьте в .env (убедитесь, что .env есть в assets pubspec.yaml).',
      );
    }
    return value;
  }
}
