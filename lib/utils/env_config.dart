import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Централизованный доступ к секретам и настройкам окружения.
///
/// Порядок приоритета:
/// 1. `--dart-define` / `--dart-define-from-file=env.defines.json` —
///    константные значения из [_compileTime] (гарантированно работают
///    в release/AOT-сборке);
/// 2. рантайм-поиск в карте dart-define (нужен только для ключей, которых
///    нет в [_compileTime]);
/// 3. `.env` через flutter_dotenv — ТОЛЬКО в debug-сборках (`kDebugMode`);
/// 4. `defaultValue`.
///
/// Файл `.env` больше не входит в `assets` (см. `pubspec.yaml`), поэтому
/// в APK он не попадает. Ключи из [_forbiddenInRelease] в release-сборке
/// не отдаются никогда: обращения к провайдеру идут через собственный
/// прокси ([aiProxyUrl]), где ключ хранится на сервере.
class EnvConfig {
  EnvConfig._();

  static bool _initialized = false;

  /// Значения, зашитые в бинарник на этапе компиляции.
  ///
  /// `String.fromEnvironment` гарантированно раскрывается компилятором
  /// только при константном обращении, поэтому все используемые ключи
  /// перечислены здесь явными константами.
  static const Map<String, String> _compileTime = <String, String>{
    // Внутренний прокси (release-сборки не содержат ключей провайдеров)
    'AI_PROXY_URL': String.fromEnvironment('AI_PROXY_URL'),

    // AI-провайдер (только debug; в release запрещён — см. [_forbiddenInRelease])
    'DEEPSEEK_API_KEY': String.fromEnvironment('DEEPSEEK_API_KEY'),

    // Внешние сервисы
    'WEATHER_API_KEY': String.fromEnvironment('WEATHER_API_KEY'),
    'GEOAPIFY_API_KEY': String.fromEnvironment('GEOAPIFY_API_KEY'),

    // Firebase (это идентификаторы проекта, а не секреты)
    'FIREBASE_ANDROID_API_KEY': String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    'FIREBASE_ANDROID_APP_ID': String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    'FIREBASE_MESSAGING_SENDER_ID':
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
    'FIREBASE_STORAGE_BUCKET': String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    'FIREBASE_IOS_API_KEY': String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    'FIREBASE_IOS_APP_ID': String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    'FIREBASE_IOS_BUNDLE_ID': String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),

    // Yandex Mobile Ads
    'YANDEX_MOBILE_ADS_APP_ID': String.fromEnvironment('YANDEX_MOBILE_ADS_APP_ID'),
    'YANDEX_BANNER_AD_UNIT_ID': String.fromEnvironment('YANDEX_BANNER_AD_UNIT_ID'),
    'YANDEX_INTERSTITIAL_AD_UNIT_ID':
        String.fromEnvironment('YANDEX_INTERSTITIAL_AD_UNIT_ID'),
    'YANDEX_NATIVE_AD_UNIT_ID': String.fromEnvironment('YANDEX_NATIVE_AD_UNIT_ID'),
  };

  /// Ключи, которые запрещено отдавать в release-сборке: они утекли бы
  /// в APK вместе с ключом биллинга. В release такие запросы обязаны идти
  /// через серверный прокси.
  static const Set<String> _forbiddenInRelease = <String>{
    'DEEPSEEK_API_KEY',
  };

  /// Адрес собственного AI-прокси, например
  /// `https://storyhero.ru/fuelmaster/ai`.
  static String get aiProxyUrl => get('AI_PROXY_URL');

  /// true — приложение обязано ходить к AI через прокси (release-режим).
  static bool get hasAiProxy => aiProxyUrl.isNotEmpty;

  static Future<void> init() async {
    if (_initialized) return;

    // .env читается только в debug: в release этот файл не входит в assets
    // и не должен содержать секретов, попадающих в APK.
    if (kDebugMode) {
      try {
        await dotenv.load(fileName: '.env', isOptional: true);
      } catch (e) {
        debugPrint('EnvConfig: .env не загружен (${e.runtimeType})');
      }
    }

    _initialized = true;
  }

  static String get(String key, {String defaultValue = ''}) {
    final compileTime = _compileTime[key];
    if (compileTime != null && compileTime.isNotEmpty) {
      return _guard(key, compileTime, defaultValue);
    }

    // Совместимость: значения, которых нет в _compileTime и переданные
    // рантайм-флагом (работает в debug/profile).
    final fromDefine = String.fromEnvironment(key, defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return _guard(key, fromDefine, defaultValue);
    }

    if (kDebugMode && _initialized) {
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
        'Соберите приложение с --dart-define-from-file=env.defines.json '
        '(шаблон — env.defines.json.example).',
      );
    }
    return value;
  }

  /// Не отдаёт секрет в release-сборке: вместо ключа провайдера
  /// используется прокси, иначе — пустая строка и явная запись в лог.
  static String _guard(String key, String value, String defaultValue) {
    if (kReleaseMode && _forbiddenInRelease.contains(key)) {
      debugPrint(
        'EnvConfig: ключ "$key" недоступен в release-сборке. '
        'Используйте AI_PROXY_URL (см. server/ai_proxy).',
      );
      return defaultValue;
    }
    return value;
  }
}
