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

# Дополнительно для фикса R8 AssertionError
-keep class com.android.tools.r8.** { *; }
-dontwarn com.android.tools.r8.**
-dontnote com.android.tools.r8.**
-dontwarn com.android.tools.r8.internal.**
-dontnote com.android.tools.r8.internal.**
-dontwarn io.netty.**
-dontnote io.netty.**
-dontwarn commons-logging.**
-dontnote commons-logging.**
-dontoptimize
-dontshrink
-dontobfuscate  # Отключение обфускации для фикса R8