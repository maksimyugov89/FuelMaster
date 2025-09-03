import 'package:flutter/material.dart';
import 'package:fuelmaster/utils/yandex_ads_channel.dart';
import 'package:fuelmaster/utils/logger.dart';

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
  static Future<void> loadInterstitialAd({required String adUnitId}) async {
    await YandexAdsChannel.loadInterstitialAd(adUnitId: adUnitId);
  }

  static Future<void> showInterstitialAd() async {
    await YandexAdsChannel.showInterstitialAd();
  }

  /// Очистка ресурсов
  static void dispose() {
    YandexAdsChannel.dispose();
    logger.d('AdManager disposed');
  }
}
