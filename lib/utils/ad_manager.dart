import 'package:flutter/material.dart';
import 'package:fuelmaster/utils/yandex_ads_channel.dart';
import 'package:fuelmaster/utils/logger.dart';

class AdManager {
  static Future<void> initialize() async {
    await YandexAdsChannel.initialize();
    logger.d('AdManager initialized');
  }

  static Widget showBannerAd(BuildContext context) {
    return YandexAdsChannel.showBannerAd(context);
  }

  static Future<void> loadNativeAd() async {
    await YandexAdsChannel.loadNativeAd();
  }

  static Widget buildNativeAdView() {
    return YandexAdsChannel.buildNativeAdView();
  }

  static Future<void> loadInterstitialAd() async {
    await YandexAdsChannel.loadInterstitialAd();
  }

  static Future<void> showInterstitialAd() async {
    await YandexAdsChannel.showInterstitialAd();
  }

  static void dispose() {
    YandexAdsChannel.dispose();
    logger.d('AdManager disposed');
  }
}