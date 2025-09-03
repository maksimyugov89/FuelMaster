import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class YandexAdsChannel {
  static const MethodChannel _channel =
      MethodChannel("com.example.fuelmaster/yandex_ads");

  /// Инициализация SDK
  static Future<void> initialize() async {
    await _channel.invokeMethod("initialize");
  }

  /// Баннер — PlatformView
  static Widget showBannerAd(BuildContext context,
      {required String adUnitId, required int width}) {
    return SizedBox(
      height: 100,
      child: AndroidView(
        viewType: "yandex_banner_ad",
        creationParams: {
          "adUnitId": adUnitId,
          "width": width,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }

  /// Нативная реклама — PlatformView
  static Widget buildNativeAdView({required String adUnitId}) {
    return SizedBox(
      height: 300,
      child: AndroidView(
        viewType: "yandex_native_ad",
        creationParams: {
          "adUnitId": adUnitId,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }

  /// Межстраничная реклама
  static Future<void> loadInterstitialAd({required String adUnitId}) async {
    await _channel.invokeMethod("loadInterstitialAd", {"adUnitId": adUnitId});
  }

  static Future<void> showInterstitialAd() async {
    await _channel.invokeMethod("showInterstitialAd");
  }

  /// Очистка ресурсов
  static void dispose() {
    _channel.invokeMethod("dispose");
  }
}
