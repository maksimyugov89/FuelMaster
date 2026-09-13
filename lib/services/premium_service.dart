import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Единственный источник правды о премиум-статусе.
///
/// До этого статус жил в трёх независимых местах: `AppSettingsProvider`
/// (prefs), `FuelCalculatorPage` (свой подписчик purchaseStream, ждавший
/// покупку с чужим productId — 'supergrok_monthly') и `HistoryPage`
/// (прямое чтение prefs). Восстановление покупок при старте не выполнялось,
/// поэтому после переустановки premium терялся до ручного restore.
///
/// Теперь: один productId, один подписчик, восстановление при старте и
/// запись статуса в prefs для офлайн-старта.
class PremiumService extends ChangeNotifier {
  PremiumService._internal();

  static final PremiumService instance = PremiumService._internal();

  bool _isPremium = false;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool get isPremium => _isPremium;

  /// Инициализация: читает сохранённый статус, подписывается на события
  /// покупок и запускает восстановление (не блокирует запуск приложения).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(AppConstants.isPremiumKey) ?? false;
    } catch (e) {
      logger.e('PremiumService: не удалось прочитать статус из prefs: $e');
    }

    try {
      final iap = InAppPurchase.instance;
      if (await iap.isAvailable()) {
        _purchaseSubscription = iap.purchaseStream.listen(
          _onPurchaseUpdates,
          onError: (Object e) => logger.e('PremiumService: ошибка потока покупок: $e'),
        );
        unawaited(restore());
      } else {
        logger.d('PremiumService: магазин недоступен, работаем по prefs');
      }
    } catch (e) {
      logger.e('PremiumService: не удалось инициализировать покупки: $e');
    }

    notifyListeners();
  }

  /// Восстановление покупок (вызывается при старте и по кнопке в настройках).
  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      logger.e('PremiumService: восстановление покупок не удалось: $e');
    }
  }

  /// Покупка премиума. Возвращает ключ ошибки локализации или null при успехе.
  Future<String?> buy() async {
    final iap = InAppPurchase.instance;
    try {
      if (!await iap.isAvailable()) {
        return 'store_unavailable';
      }

      final ProductDetailsResponse response =
          await iap.queryProductDetails({AppConstants.premiumProductId});
      if (response.productDetails.isEmpty) {
        logger.e(
          'PremiumService: товар ${AppConstants.premiumProductId} не найден '
          '(error: ${response.error?.message})',
        );
        return 'product_not_found';
      }

      await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
      return null;
    } catch (e) {
      logger.e('PremiumService: ошибка покупки: $e');
      return 'error';
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConstants.premiumProductId) {
        logger.d('PremiumService: пропускаю чужой товар ${purchase.productID}');
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _updatePremium(true);
      } else if (purchase.status == PurchaseStatus.error) {
        logger.e('PremiumService: покупка с ошибкой: ${purchase.error}');
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          logger.e('PremiumService: не удалось завершить покупку: $e');
        }
      }
    }
  }

  Future<void> _updatePremium(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.isPremiumKey, value);
    } catch (e) {
      logger.e('PremiumService: не удалось сохранить статус: $e');
    }
    logger.d('PremiumService: статус премиума = $value');
    notifyListeners();
  }

  /// Смена статуса извне (настройки, тесты, отладка).
  Future<void> setPremium(bool value) => _updatePremium(value);
}
