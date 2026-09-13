import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fuelmaster/services/entitlement_client.dart';

/// A-7 аудита: вердикт о премиуме даёт сервер, клиентский prefs — только кэш.
/// Тесты фиксируют главное правило: статус меняется ТОЛЬКО при HTTP 200.
void main() {
  const String base = 'https://proxy.example/fuelmaster/ai';

  EntitlementClient clientWith(
    Future<http.Response> Function(http.Request request) handler, {
    String url = base,
  }) =>
      EntitlementClient(httpClient: MockClient(handler), baseUrl: url);

  group('EntitlementClient', () {
    test('прокси не настроен — вердикта нет, запрос никуда не уходит', () async {
      final client = clientWith(
        (_) async => fail('запрос не должен уходить без AI_PROXY_URL'),
        url: '',
      );

      expect(client.isConfigured, isFalse);
      final status = await client.fetchStatus();

      expect(status.reachable, isFalse);
      expect(status.reason, 'proxy_not_configured');
    });

    test('POST /v1/entitlement передаёт чек и product_id', () async {
      late http.Request captured;
      final client = clientWith((request) async {
        captured = request;
        return http.Response(jsonEncode({'premium': true}), 200);
      });

      final status = await client.verifyPurchase(
        purchaseToken: 'token-123',
        productId: 'fuelmaster_premium',
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$base/v1/entitlement');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['purchase_token'], 'token-123');
      expect(body['product_id'], 'fuelmaster_premium');
      expect(status.reachable, isTrue);
      expect(status.premium, isTrue);
    });

    test('200 premium:false — сервер проверил чек и снял премиум', () async {
      final client = clientWith(
        (_) async => http.Response(
          jsonEncode({'premium': false, 'reason': 'purchase_not_found'}),
          200,
        ),
      );

      final status = await client.fetchStatus();

      expect(status.reachable, isTrue);
      expect(status.premium, isFalse);
      expect(status.reason, 'purchase_not_found');
    });

    test('503 (проверка недоступна) не считается вердиктом', () async {
      final client = clientWith(
        (_) async => http.Response('{"detail":"verification_unavailable"}', 503),
      );

      final status = await client.fetchStatus();

      expect(status.reachable, isFalse);
      expect(status.reason, 'http_503');
      expect(status.premium, isNull);
    });

    test('401 не считается вердиктом', () async {
      final client = clientWith((_) async => http.Response('{}', 401));

      final status = await client.verifyPurchase(
        purchaseToken: 't',
        productId: 'p',
      );

      expect(status.reachable, isFalse);
      expect(status.premium, isNull);
    });

    test('битый JSON не роняет сервис', () async {
      final client = clientWith(
        (_) async => http.Response(
          'не json',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final status = await client.fetchStatus();

      expect(status.reachable, isFalse);
      expect(status.reason, 'bad_json');
    });

    test('сетевое исключение обрабатывается', () async {
      final client = clientWith((_) async => throw const SocketExceptionStub());

      final status = await client.fetchStatus();

      expect(status.reachable, isFalse);
      expect(status.premium, isNull);
    });
  });
}

/// Минимальная заглушка сетевой ошибки (без dart:io — тест идёт и на web).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub';
}
