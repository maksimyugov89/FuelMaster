import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fuelmaster/utils/logger.dart';

class YandexAdsChannel {
  static final String bannerAdUnitId = dotenv.env['YANDEX_BANNER_AD_UNIT_ID'] ?? '';
  static final String nativeAdUnitId = dotenv.env['YANDEX_NATIVE_AD_UNIT_ID'] ?? '';
  static final String interstitialAdUnitId = dotenv.env['YANDEX_INTERSTITIAL_AD_UNIT_ID'] ?? '';

  static const platform = MethodChannel('com.example.fuelmaster/yandex_ads');

  static Future<void> initialize() async {
    try {
      await platform.invokeMethod('initialize');
      logger.d('Yandex Mobile Ads SDK initialized via platform channel');
    } catch (e) {
      logger.e('Error initializing Yandex Ads: $e');
      rethrow;
    }
  }

  static Widget showBannerAd(BuildContext context) {
    return _PlatformBannerAd(
      adUnitId: bannerAdUnitId,
      width: MediaQuery.of(context).size.width.toInt(),
    );
  }

  static Future<void> loadNativeAd({int retryCount = 3}) async {
    logger.d('Loading native ad with ID: $nativeAdUnitId');
    for (int i = 0; i < retryCount; i++) {
      try {
        await platform.invokeMethod('loadNativeAd', {'adUnitId': nativeAdUnitId});
        logger.d('Native ad loaded successfully');
        return;
      } catch (e) {
        logger.e('Failed to load native ad (attempt ${i + 1}): $e');
        if (i == retryCount - 1) {
          logger.e('Max retries reached for native ad');
          rethrow;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  static Widget buildNativeAdView() {
    return const _PlatformNativeAdView();
  }

  static Future<void> loadInterstitialAd({int retryCount = 3}) async {
    logger.d('Loading interstitial ad with ID: $interstitialAdUnitId');
    for (int i = 0; i < retryCount; i++) {
      try {
        await platform.invokeMethod('loadInterstitialAd', {'adUnitId': interstitialAdUnitId});
        logger.d('Interstitial ad loaded successfully');
        return;
      } catch (e) {
        logger.e('Failed to load interstitial ad (attempt ${i + 1}): $e');
        if (i == retryCount - 1) {
          logger.e('Max retries reached for interstitial ad');
          rethrow;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  static Future<void> showInterstitialAd() async {
    logger.d('Showing interstitial ad');
    try {
      await platform.invokeMethod('showInterstitialAd');
      logger.d('Interstitial ad shown');
    } catch (e) {
      logger.e('Interstitial ad failed: $e');
    }
  }

  static void dispose() {
    logger.d('Disposing YandexAdsChannel resources');
    platform.invokeMethod('dispose');
  }
}

class _PlatformBannerAd extends StatelessWidget {
  final String adUnitId;
  final int width;

  const _PlatformBannerAd({required this.adUnitId, required this.width});

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'yandex_banner_ad',
      creationParams: {
        'adUnitId': adUnitId,
        'width': width,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        YandexAdsChannel.platform.invokeMethod('loadBannerAd', {
          'viewId': id,
          'adUnitId': adUnitId,
        });
      },
    );
  }
}

class _PlatformNativeAdView extends StatelessWidget {
  const _PlatformNativeAdView();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300, // Можно сделать динамической, если нужно
      child: AndroidView(
        viewType: 'yandex_native_ad',
        creationParams: {
          'adUnitId': YandexAdsChannel.nativeAdUnitId,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          // Удалено: YandexAdsChannel.loadNativeAd(); // Загрузка теперь только в Kotlin-view, чтобы избежать дублирования
        },
      ),
    );
  }
}