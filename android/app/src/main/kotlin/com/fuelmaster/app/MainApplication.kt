package com.fuelmaster.app

import android.app.Application
import android.content.pm.PackageManager
import android.util.Log
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    private val tag = "MainApplication"

    override fun onCreate() {
        super.onCreate()
        try {
            val apiKey = readMetaDataString("com.yandex.maps.apikey")
            if (!apiKey.isNullOrBlank()) {
                MapKitFactory.setApiKey(apiKey)
                MapKitFactory.setLocale("ru_RU")
                Log.d(tag, "Yandex MapKit initialized from manifest meta-data.")
            } else {
                Log.w(tag, "Yandex MapKit API key is missing. Set yandex.maps.apikey in android/local.properties")
            }
        } catch (e: Exception) {
            Log.e(tag, "Error initializing Yandex MapKit.", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun readMetaDataString(key: String): String? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            appInfo.metaData?.getString(key)
        } catch (e: Exception) {
            Log.e(tag, "Failed to read meta-data key: $key", e)
            null
        }
    }
}
