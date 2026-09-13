package com.example.fuelmaster

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.yandex.mobile.ads.common.MobileAds
import com.yandex.mobile.ads.banner.BannerAdView
import com.yandex.mobile.ads.banner.BannerAdSize
import com.yandex.mobile.ads.banner.BannerAdEventListener
import com.yandex.mobile.ads.nativeads.*
import com.yandex.mobile.ads.interstitial.*
import com.yandex.mobile.ads.common.*
import android.util.Log
import android.view.View
import android.view.LayoutInflater
import com.example.fuelmaster.R
import com.yandex.mapkit.MapKitFactory
import com.unact.yandexmapkit.YandexMapkitPlugin

class MainActivity : FlutterFragmentActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.example.fuelmaster/yandex_ads"
    private var interstitialAd: InterstitialAd? = null
    private var interstitialAdLoader: InterstitialAdLoader? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        
        
        
        super.configureFlutterEngine(flutterEngine)

        // --- Инициализация рекламы ---
        MobileAds.initialize(this) {
            Log.d(TAG, "Yandex Mobile Ads SDK initialized")
        }

        // --- Регистрируем фабрики баннера и нативки ---
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "yandex_banner_ad",
            YandexBannerAdViewFactory()
        )

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "yandex_native_ad",
            YandexNativeAdViewFactory()
        )

        // --- Канал для interstitial ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.success(null)
                "loadBannerAd" -> result.success(null)
                "loadNativeAd" -> result.success(null)
                "loadInterstitialAd" -> {
                    val adUnitId = call.argument<String>("adUnitId")
                    if (adUnitId != null) {
                        loadInterstitialAd(adUnitId)
                        result.success(null)
                    } else {
                        result.error("INVALID_AD_UNIT", "AdUnitId is null", null)
                    }
                }
                "showInterstitialAd" -> {
                    showInterstitialAd()
                    result.success(null)
                }
                "dispose" -> {
                    destroyInterstitialAd()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- Interstitial ---
    private fun loadInterstitialAd(adUnitId: String) {
        interstitialAdLoader = InterstitialAdLoader(this).apply {
            setAdLoadListener(object : InterstitialAdLoadListener {
                override fun onAdLoaded(interstitialAd: InterstitialAd) {
                    this@MainActivity.interstitialAd = interstitialAd
                    Log.d(TAG, "Interstitial ad loaded")
                }
                override fun onAdFailedToLoad(error: AdRequestError) {
                    Log.e(TAG, "Interstitial ad failed to load: ${error.description}")
                    this@MainActivity.interstitialAd = null
                }
            })
        }
        val adRequestConfiguration = AdRequestConfiguration.Builder(adUnitId).build()
        interstitialAdLoader?.loadAd(adRequestConfiguration)
    }

    private fun showInterstitialAd() {
        interstitialAd?.apply {
            setAdEventListener(object : InterstitialAdEventListener {
                override fun onAdShown() { Log.d(TAG, "Interstitial ad shown") }
                override fun onAdFailedToShow(adError: AdError) {
                    Log.e(TAG, "Interstitial ad failed to show: ${adError.description}")
                    destroyInterstitialAd()
                }
                override fun onAdDismissed() {
                    Log.d(TAG, "Interstitial ad dismissed")
                    destroyInterstitialAd()
                }
                override fun onAdClicked() { Log.d(TAG, "Interstitial ad clicked") }
                override fun onAdImpression(impressionData: ImpressionData?) {
                    Log.d("YandexNativeAdView", "Interstitial ad impression: $impressionData")
                }
            })
            show(this@MainActivity)
        } ?: Log.e(TAG, "Interstitial ad is not loaded")
    }

    private fun destroyInterstitialAd() {
        interstitialAd?.setAdEventListener(null)
        interstitialAd = null
        interstitialAdLoader?.setAdLoadListener(null)
        interstitialAdLoader = null
    }
}

// ---- Banner View ----
class YandexBannerAdViewFactory : PlatformViewFactory(StandardMessageCodec()) {
    override fun create(context: android.content.Context, viewId: Int, args: Any?): PlatformView {
        val params = args as Map<*, *>
        val adUnitId = params["adUnitId"] as String
        val width = params["width"] as Int
        return YandexBannerAdView(context, adUnitId, width)
    }
}

class YandexBannerAdView(
    private val context: android.content.Context,
    private val adUnitId: String,
    private val width: Int
) : PlatformView {
    private val bannerAdView: BannerAdView = BannerAdView(context)

    init {
        bannerAdView.setAdUnitId(adUnitId)
        bannerAdView.setAdSize(BannerAdSize.stickySize(context, width))
        bannerAdView.setBannerAdEventListener(object : BannerAdEventListener {
            override fun onAdLoaded() { Log.d("YandexBannerAdView", "Banner ad loaded") }
            override fun onAdFailedToLoad(error: AdRequestError) {
                Log.e("YandexBannerAdView", "Banner ad failed to load: ${error.description}")
            }
            override fun onAdClicked() { Log.d("YandexBannerAdView", "Banner ad clicked") }
            override fun onLeftApplication() { Log.d("YandexBannerAdView", "User left application after banner click") }
            override fun onReturnedToApplication() { Log.d("YandexBannerAdView", "User returned after banner click") }
            override fun onImpression(impressionData: ImpressionData?) {
                Log.d("YandexBannerAdView", "Banner ad impression: $impressionData")
            }
        })
        bannerAdView.loadAd(AdRequest.Builder().build())
    }

    override fun getView(): View = bannerAdView
    override fun dispose() {
        bannerAdView.destroy()
        Log.d("YandexBannerAdView", "Banner ad disposed")
    }
}

// ---- Native View ----
class YandexNativeAdViewFactory : PlatformViewFactory(StandardMessageCodec()) {
    override fun create(context: android.content.Context, viewId: Int, args: Any?): PlatformView {
        val params = args as Map<*, *>
        val adUnitId = params["adUnitId"] as String
        return YandexNativeAdView(context, adUnitId)
    }
}

class YandexNativeAdView(
    private val context: android.content.Context,
    private val adUnitId: String
) : PlatformView {
    private val nativeAdView: NativeAdView = NativeAdView(context)
    private var nativeAdLoader: NativeAdLoader? = null

    init {
        val inflater = LayoutInflater.from(context)
        inflater.inflate(R.layout.native_ad_layout, nativeAdView, true)

        nativeAdLoader = NativeAdLoader(context).apply {
            setNativeAdLoadListener(object : NativeAdLoadListener {
                override fun onAdLoaded(nativeAd: NativeAd) {
                    Log.d("YandexNativeAdView", "Native ad loaded")
                    try {
                        val binder = NativeAdViewBinder.Builder(nativeAdView)
                            .setTitleView(nativeAdView.findViewById(R.id.title))
                            .setBodyView(nativeAdView.findViewById(R.id.body))
                            .setCallToActionView(nativeAdView.findViewById(R.id.call_to_action))
                            .setMediaView(nativeAdView.findViewById(R.id.media))
                            .setDomainView(nativeAdView.findViewById(R.id.domain))
                            .setWarningView(nativeAdView.findViewById(R.id.warning))
                            .setSponsoredView(nativeAdView.findViewById(R.id.sponsored))
                            .setFeedbackView(nativeAdView.findViewById(R.id.feedback))
                            .setIconView(nativeAdView.findViewById(R.id.icon))
                            .setPriceView(nativeAdView.findViewById(R.id.price))
                            .build()
                        nativeAd.bindNativeAd(binder)
                        nativeAd.setNativeAdEventListener(object : NativeAdEventListener {
                            override fun onAdClicked() { Log.d("YandexNativeAdView", "Native ad clicked") }
                            override fun onLeftApplication() { Log.d("YandexNativeAdView", "User left app after native ad click") }
                            override fun onReturnedToApplication() { Log.d("YandexNativeAdView", "User returned after native ad click") }
                            override fun onImpression(impressionData: ImpressionData?) {
                                Log.d("YandexNativeAdView", "Native ad impression: $impressionData")
                            }
                        })
                    } catch (e: Exception) {
                        Log.e("YandexNativeAdView", "Native ad binding error: ${e.message}")
                    }
                }
                override fun onAdFailedToLoad(error: AdRequestError) {
                    Log.e("YandexNativeAdView", "Native ad failed to load: ${error.description}")
                }
            })
        }
        val adRequestConfiguration = NativeAdRequestConfiguration.Builder(adUnitId).build()
        nativeAdLoader?.loadAd(adRequestConfiguration)
    }

    override fun getView(): View = nativeAdView
    override fun dispose() {
        nativeAdLoader?.cancelLoading()
        nativeAdLoader?.setNativeAdLoadListener(null)
        nativeAdLoader = null
        nativeAdView.removeAllViews()
        Log.d("YandexNativeAdView", "Native ad disposed")
    }
}
