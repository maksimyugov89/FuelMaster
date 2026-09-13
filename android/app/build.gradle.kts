import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        load(localPropertiesFile.inputStream())
    }
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val yandexMapsApiKey: String = localProperties.getProperty("yandex.maps.apikey", "")
android {
    namespace = "com.fuelmaster.app"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Сохраняем идентификатор опубликованной версии RuStore, чтобы новая
        // версия устанавливалась как обновление существующего FuelMaster.
        applicationId = "com.example.fuelmaster"
        minSdk = 26
        targetSdk = 36
        // Единственный источник версии — pubspec.yaml (`version: 1.0.1+7`).
        // Раньше здесь были зашиты versionCode = 1 / versionName = "1.0.0",
        // поэтому все сборки выходили одной и той же версией.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        manifestPlaceholders["YANDEX_MAPS_API_KEY"] = yandexMapsApiKey
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    buildFeatures {
        viewBinding = true
    }

    packaging {
        resources {
            excludes.add("/META-INF/{AL2.0,LGPL2.1}")
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.work:work-runtime:2.8.1")
        force("androidx.work:work-runtime-ktx:2.8.1")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.google.android.material:material:1.12.0")
    implementation(platform("com.google.firebase:firebase-bom:33.3.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-appcheck-playintegrity:18.0.0")
    implementation("com.google.firebase:firebase-appcheck-debug:18.0.0")
    implementation("com.yandex.android:mobileads:7.15.1")
    implementation("com.yandex.android:mobileads-mediation:7.15.1.0")
    implementation("com.yandex.ads.mediation:mobileads-mytarget:5.27.2.0")
    implementation("com.my.tracker:mytracker-sdk:3.5.0")
    implementation("androidx.multidex:multidex:2.0.1")
    flutter {
        source = "../.."
    }

    implementation("com.yandex.android:maps.mobile:4.6.1-full")
}
