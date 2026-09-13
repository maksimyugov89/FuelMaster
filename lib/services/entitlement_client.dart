import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:fuelmaster/utils/env_config.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Вердикт сервера о премиум-статусе (A-7 аудита).
class EntitlementStatus {
  const EntitlementStatus({required this.reachable, this.premium, this.reason});

  /// Сервер дал вердикт (HTTP 200). `false` — прокси не настроен, сеть или
  /// ошибка: локальный статус в этом случае НЕ меняем (офлайн-первый режим).
  final bool reachable;

  /// Подтверждён ли премиум сервером.
  final bool? premium;

  /// Причина для лога и диагностики.
  final String? reason;
}

/// Серверная проверка премиума.
///
/// Клиентский флаг в prefs — только офлайн-кэш: он выставляется по событиям
/// магазина, но подтверждает статус прокси: проверяет чек Google Play и
/// пишет entitlement в Firestore. Пока `AI_PROXY_URL` не задан, класс честно
/// сообщает `reachable: false`, и [PremiumService] работает как раньше.
class EntitlementClient {
  EntitlementClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _http;
  final String? _baseUrlOverride;

  String? get _baseUrl {
    final base = _baseUrlOverride ?? EnvConfig.aiProxyUrl;
    if (base.isEmpty) return null;
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  /// Настроен ли прокси (иначе проверять нечего).
  bool get isConfigured => _baseUrl != null;

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    // Всё в try: `FirebaseAuth.instance` бросает, если Firebase ещё не поднят
    // (тесты, ранний вызов) — без токена запрос уйдёт и получит 401, а не упадёт.
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      logger.e('EntitlementClient: не удалось получить ID token: $e');
    }
    return headers;
  }

  /// Подтверждает покупку: сервер проверяет чек у Google Play.
  Future<EntitlementStatus> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final base = _baseUrl;
    if (base == null) {
      return const EntitlementStatus(
        reachable: false,
        reason: 'proxy_not_configured',
      );
    }
    try {
      final response = await _http
          .post(
            Uri.parse('$base/v1/entitlement'),
            headers: await _headers(),
            body: jsonEncode({
              'purchase_token': purchaseToken,
              'product_id': productId,
            }),
          )
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      logger.e('EntitlementClient: сервер недоступен ($e)');
      return EntitlementStatus(
        reachable: false,
        reason: e.runtimeType.toString(),
      );
    }
  }

  /// Текущий статус с сервера (вызывается при старте приложения).
  Future<EntitlementStatus> fetchStatus() async {
    final base = _baseUrl;
    if (base == null) {
      return const EntitlementStatus(
        reachable: false,
        reason: 'proxy_not_configured',
      );
    }
    try {
      final response = await _http
          .get(Uri.parse('$base/v1/entitlement'), headers: await _headers())
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      logger.e('EntitlementClient: сервер недоступен ($e)');
      return EntitlementStatus(
        reachable: false,
        reason: e.runtimeType.toString(),
      );
    }
  }

  /// Вердиктом считается только 200. Прочие коды (401, 429, 503) означают
  /// «сервер не подтвердил»: статус премиума менять нельзя, иначе платящий
  /// пользователь потеряет доступ из-за сетевой ошибки.
  EntitlementStatus _parse(http.Response response) {
    if (response.statusCode != 200) {
      return EntitlementStatus(
        reachable: false,
        reason: 'http_${response.statusCode}',
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final premium = data['premium'];
        if (premium is bool) {
          return EntitlementStatus(
            reachable: true,
            premium: premium,
            reason: data['reason'] as String?,
          );
        }
      }
      return const EntitlementStatus(reachable: false, reason: 'bad_payload');
    } catch (e) {
      logger.e('EntitlementClient: не разобрал ответ сервера: $e');
      return const EntitlementStatus(reachable: false, reason: 'bad_json');
    }
  }
}
