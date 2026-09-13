import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/env_config.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Советы по экономии топлива от AI-провайдера.
///
/// В release-сборках запрос идёт ТОЛЬКО через собственный прокси
/// (`AI_PROXY_URL`, см. `server/ai_proxy`): ключ провайдера в APK не попадает.
/// Прямое обращение к OpenRouter остаётся для debug-сборок, когда прокси
/// ещё не задан и в `.env` есть `DEEPSEEK_API_KEY`.
class DeepSeekService {
  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  static const String _directModel = 'deepseek/deepseek-r1-0528:free';
  static const Duration _requestTimeout = Duration(seconds: 60);

  /// Прямой ключ провайдера (в release всегда пустой).
  String get _directApiKey => EnvConfig.get('DEEPSEEK_API_KEY');

  bool get _useProxy => EnvConfig.hasAiProxy;

  Uri get _endpoint {
    if (_useProxy) {
      final base = EnvConfig.aiProxyUrl.replaceAll(RegExp(r'/+$'), '');
      return Uri.parse('$base/v1/advice');
    }
    return Uri.parse('https://openrouter.ai/api/v1/chat/completions');
  }

  Future<String?> getCachedAdvice(String carModel) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('deepseek_advice_$carModel');
    final timestamp = prefs.getInt('deepseek_advice_timestamp_$carModel') ?? 0;
    if (cached != null &&
        cached.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch - timestamp < 7 * 24 * 60 * 60 * 1000) {
      logger.d('Using cached advice for $carModel');
      return cached;
    }
    return null;
  }

  Future<void> cacheAdvice(String carModel, String advice) async {
    if (advice.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deepseek_advice_$carModel', advice);
      await prefs.setInt(
          'deepseek_advice_timestamp_$carModel', DateTime.now().millisecondsSinceEpoch);
      logger.d('Cached advice for $carModel');
    }
  }

  /// Заголовки запроса: к прокси — токен Firebase, напрямую — ключ провайдера.
  Future<Map<String, String>> _headers() async {
    const jsonHeaders = {'Content-Type': 'application/json'};

    if (!_useProxy) {
      return {...jsonHeaders, 'Authorization': 'Bearer $_directApiKey'};
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return jsonHeaders;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return jsonHeaders;
      return {...jsonHeaders, 'Authorization': 'Bearer $idToken'};
    } catch (e) {
      logger.e('Не удалось получить Firebase ID token: $e');
      return jsonHeaders;
    }
  }

  /// Тело запроса: прокси получает только промпт и модель автомобиля,
  /// прямой режим — полный OpenAI-совместимый payload.
  String _body(String carModel, String prompt) {
    if (_useProxy) {
      return jsonEncode({'car_model': carModel, 'prompt': prompt});
    }
    return jsonEncode({
      'model': _directModel,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': 1700,
    });
  }

  String? _extractAdvice(String responseBody) {
    final data = jsonDecode(responseBody);
    if (data is! Map<String, dynamic>) return null;
    if (_useProxy) {
      final advice = data['advice'];
      return advice is String && advice.isNotEmpty ? advice : null;
    }
    return data['choices']?[0]?['message']?['content'] as String?;
  }

  /// B-13: принимает `AppLocalizations`, а не `BuildContext`: вызов идёт
  /// после await, и передавать туда контекст нельзя. Сообщение об ошибке
  /// показывает вызывающий экран (он и так рисует его при пустом ответе).
  /// B-13: текст последней ошибки AI, чтобы экран мог показать его без
  /// BuildContext (сервис вызывается после await).
  String? lastErrorMessage;

  Future<String?> getFuelEfficiencyAdvice(
      String carModel, AppLocalizations l10n, Map<String, dynamic>? calculationRecord) async {
    lastErrorMessage = null;
    if (!_useProxy && _directApiKey.isEmpty) {
      logger.e('AI недоступен: не задан AI_PROXY_URL и нет ключа провайдера');
      return null;
    }

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        String prompt =
            'Дайте детальные и специфические советы на русском языке по оптимизации расхода топлива для автомобиля $carModel с учетом опыта водителя со стажем более 5 лет. ';
        if (calculationRecord != null) {
          prompt += 'Используйте следующие данные: '
              'общий пробег: ${calculationRecord['total_mileage']} км, '
              'городской пробег: ${calculationRecord['city_mileage']} км, '
              'трассовый пробег: ${calculationRecord['highway_mileage']} км, '
              'норма расхода в городе: ${calculationRecord['base_city_norm']} л/100 км, '
              'норма расхода на трассе: ${calculationRecord['base_highway_norm']} л/100 км, '
              'условия: зима=${calculationRecord['conditions']['winter'] > 1.0 ? 'да' : 'нет'}, '
              'кондиционер=${calculationRecord['conditions']['ac'] > 1.0 ? 'да' : 'нет'}, '
              'горы=${calculationRecord['conditions']['mountain'] > 1.0 ? 'да' : 'нет'}, '
              'начальный уровень топлива: ${calculationRecord['initial_fuel']} л, '
              'дозаправка: ${calculationRecord['refuel']} л. '
              'Сфокусируйтесь на техническом обслуживании, оптимизации маршрутов, настройке двигателя и шин, избегая общих фраз типа "плавный разгон".';
        } else {
          prompt += 'Предоставьте рекомендации, ориентированные на опытных водителей, без общих советов.';
        }

        final response = await http
            .post(
              _endpoint,
              headers: await _headers(),
              body: _body(carModel, prompt),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final advice = _extractAdvice(response.body);
          if (advice != null && advice.isNotEmpty) {
            return advice;
          }
          logger.e('AI вернул пустой ответ (попытка $retryCount)');
          retryCount++;
          if (retryCount <= maxRetries) await Future.delayed(const Duration(seconds: 2));
        } else if (response.statusCode == 402) {
          logger.e('AI: 402, ${l10n.insufficient_balance}');
          lastErrorMessage = l10n.insufficient_balance;
          return null;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          logger.e('AI: отказ авторизации (${response.statusCode})');
          lastErrorMessage = l10n.error;
          return null;
        } else {
          logger.e('AI error: ${response.statusCode}');
          lastErrorMessage = l10n.error;
          return null;
        }
      } on TimeoutException {
        logger.e('AI: таймаут запроса (попытка $retryCount)');
        retryCount++;
        if (retryCount <= maxRetries) await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        logger.e('AI exception: ${e.runtimeType} (попытка $retryCount)');
        retryCount++;
        if (retryCount <= maxRetries) await Future.delayed(const Duration(seconds: 2));
      }
    }

    logger.e('Max retries reached for $carModel');
    lastErrorMessage = l10n.error;
    return null;
  }
}
