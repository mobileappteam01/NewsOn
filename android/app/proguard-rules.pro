# Google Mobile Ads / AdMob
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Services
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# WebView used by GMA SDK
-keep class androidx.webkit.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
