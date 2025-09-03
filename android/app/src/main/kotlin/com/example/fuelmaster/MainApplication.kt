package com.example.fuelmaster

import android.app.Application
import com.yandex.mapkit.MapKitFactory
import android.util.Log

class MainApplication : Application() {
    private val TAG = "MainApplication"

    override fun onCreate() {
        super.onCreate()
        try {
            MapKitFactory.setApiKey("YANDEX_MAPS_API_KEY_REMOVED") // Ваш сгенерированный API ключ
            MapKitFactory.setLocale("ru_RU") // Ваш предпочтительный язык. Необязательно, по умолчанию используется системный язык
            Log.d(TAG, "Yandex MapKit API key and locale set successfully in MainApplication.")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting MapKit API key or locale in MainApplication.", e)
        }
    }
}