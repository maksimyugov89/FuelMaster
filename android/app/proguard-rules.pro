# Базовые правила для Android
-keep public class * extends androidx.appcompat.app.AppCompatActivity
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference
-keep public class com.android.vending.billing.IInAppBillingService

# Правила для Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Правила для Yandex Ads и mediation
-keep class com.yandex.mobile.ads.** { *; }
-dontwarn com.yandex.mobile.ads.**
-keep class com.ironsource.** { *; }
-dontwarn com.ironsource.**
-keep class com.my.target.** { *; }
-dontwarn com.my.target.**
-keep class com.my.tracker.** { *; }
-dontwarn com.my.tracker.**

# Правила для Gson и библиотек из логов
-keep class com.google.gson.** { *; }
-keep class org.checkerframework.** { *; }
-dontwarn org.checkerframework.**
-keep class org.codehaus.mojo.animal_sniffer.** { *; }
-dontwarn org.codehaus.mojo.animal_sniffer.**
-keep class org.chromium.net.** { *; }
-dontwarn org.chromium.net.**

# Правила для MultiDex
-keep class androidx.multidex.MultiDex { *; }
-keepclassmembers class ** {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn sun.misc.Unsafe
-dontwarn javax.annotation.**

# Правила для WebView/JS
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Отсутствующие классы-заглушки в сторонних SDK: без -dontwarn R8 валится
# на missing-class warnings при включённой минификации.
-dontwarn io.netty.**
-dontnote io.netty.**
-dontwarn commons-logging.**
-dontnote commons-logging.**

# ВНИМАНИЕ: здесь больше нет -dontoptimize / -dontshrink / -dontobfuscate.
# Эти три правила полностью отменяли isMinifyEnabled/isShrinkResources из
# android/app/build.gradle.kts: release-APK не обфусцировался и не ужимался,
# а имена классов оставались снаружи. Выше — только конкретные -keep для
# библиотек, которые работают через рефлексию.