import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';

class DeepSeekService {
  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  final String _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';

  Future<String?> getCachedAdvice(String carModel) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('deepseek_advice_$carModel');
    final timestamp = prefs.getInt('deepseek_advice_timestamp_$carModel') ?? 0;
    if (cached != null && cached.isNotEmpty && DateTime.now().millisecondsSinceEpoch - timestamp < 7 * 24 * 60 * 60 * 1000) {
      logger.d('Using cached advice for $carModel');
      return cached;
    }
    return null;
  }

  Future<void> cacheAdvice(String carModel, String advice) async {
    if (advice.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deepseek_advice_$carModel', advice);
      await prefs.setInt('deepseek_advice_timestamp_$carModel', DateTime.now().millisecondsSinceEpoch);
      logger.d('Cached advice for $carModel');
    }
  }

  Future<String?> getFuelEfficiencyAdvice(String carModel, BuildContext context, Map<String, dynamic>? calculationRecord) async {
    final l10n = AppLocalizations.of(context)!;
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        String prompt = 'Дайте детальные и специфические советы на русском языке по оптимизации расхода топлива для автомобиля $carModel с учетом опыта водителя со стажем более 5 лет. ';
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

        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': 'deepseek/deepseek-r1-0528:free',
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': 1700,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final advice = data['choices']?[0]?['message']?['content'] as String?;
          logger.d('DeepSeek API raw response: ${response.body}');
          if (advice != null && advice.isNotEmpty) {
            logger.d('DeepSeek API response: $advice');
            return advice;
          } else {
            logger.e('DeepSeek API returned null or empty response (attempt $retryCount)');
            retryCount++;
            if (retryCount <= maxRetries) await Future.delayed(const Duration(seconds: 2));
          }
        } else if (response.statusCode == 402) {
          logger.e('DeepSeek API error: 402, ${l10n.insufficient_balance}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.insufficient_balance)),
            );
          }
          return null;
        } else {
          logger.e('DeepSeek API error: ${response.statusCode}, ${response.body}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.error)),
            );
          }
          return null;
        }
      } catch (e) {
        logger.e('DeepSeek API exception: $e (attempt $retryCount)');
        retryCount++;
        if (retryCount <= maxRetries) await Future.delayed(const Duration(seconds: 2));
      }
    }
    logger.e('Max retries reached for $carModel');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
    }
    return null;
  }
}