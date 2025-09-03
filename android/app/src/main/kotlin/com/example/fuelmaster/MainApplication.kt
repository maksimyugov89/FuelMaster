package com.example.fuelmaster

import android.app.Application
import com.yandex.mapkit.MapKitFactory
import android.util.Log

class MainApplication : Application() {
    private val TAG = "MainApplication"

    override fun onCreate() {
        super.onCreate()
        try {
            MapKitFactory.setApiKey("5ca14097-6f12-48fd-823e-55811fe3b956") // Ваш сгенерированный API ключ
            MapKitFactory.setLocale("ru_RU") // Ваш предпочтительный язык. Необязательно, по умолчанию используется системный язык
            Log.d(TAG, "Yandex MapKit API key and locale set successfully in MainApplication.")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting MapKit API key or locale in MainApplication.", e)
        }
    }
}