import 'package:flutter/material.dart';
import 'package:fuelmaster/utils/yandex_ads_channel.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Идентификаторы блоков рекламы (B-9) — реэкспорт, чтобы экраны не тянули
/// второй импорт: `ad_manager.dart` они уже импортируют.
export 'package:fuelmaster/utils/ad_ids.dart';

class AdManager {
  /// Инициализация SDK
  static Future<void> initialize() async {
    await YandexAdsChannel.initialize();
    logger.d('AdManager initialized');
  }

  /// Баннерная реклама
  static Widget showBannerAd({
    required BuildContext context,
    required String adUnitId,
    required int width,
  }) {
    return YandexAdsChannel.showBannerAd(
      context,
      adUnitId: adUnitId,
      width: width,
    );
  }

  /// Нативная реклама
  static Widget buildNativeAdView({required String adUnitId}) {
    return YandexAdsChannel.buildNativeAdView(adUnitId: adUnitId);
  }

  /// Межстраничная реклама
  ///
  /// B-9 аудита: `loadInterstitialAd` не вызывался нигде, а показ исправно
  /// дёргался из калькулятора — нативная сторона получала «покажи то, чего
  /// нет». Теперь рекламу грузят заранее, а показ идёт только по загруженному.
  static bool _interstitialLoaded = false;

  static bool get isInterstitialLoaded => _interstitialLoaded;

  static Future<void> loadInterstitialAd({required String adUnitId}) async {
    if (adUnitId.isEmpty) {
      logger.d('Межстраничная реклама не настроена: пустой adUnitId');
      return;
    }
    try {
      await YandexAdsChannel.loadInterstitialAd(adUnitId: adUnitId);
      _interstitialLoaded = true;
      logger.d('Межстраничная реклама загружена');
    } catch (e) {
      _interstitialLoaded = false;
      logger.e('Не удалось загрузить межстраничную рекламу: $e');
    }
  }

  /// Инстанс одноразовый: после показа помечаем израсходованным и требуем
  /// следующую загрузку.
  static Future<void> showInterstitialAd() async {
    if (!_interstitialLoaded) {
      logger.d('Показ межстраничной рекламы пропущен: не загружена');
      return;
    }
    _interstitialLoaded = false;
    try {
      await YandexAdsChannel.showInterstitialAd();
    } catch (e) {
      logger.e('Ошибка показа межстраничной рекламы: $e');
    }
  }

  /// Очистка ресурсов
  static void dispose() {
    YandexAdsChannel.dispose();
    logger.d('AdManager disposed');
  }
}
