package com.app.newson

import android.os.Bundle
import android.webkit.WebView
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    // AudioServiceActivity handles the Flutter engine configuration
    // for background audio playback

    override fun onCreate(savedInstanceState: Bundle?) {
        // Warm WebView / JavascriptEngine before AdMob loads banners.
        // Without this, cold-start BannerAd.load() often fails with
        // "Unable to obtain a JavascriptEngine" on Xiaomi and similar OEMs.
        try {
            WebView(applicationContext).apply {
                settings.javaScriptEnabled = true
                destroy()
            }
        } catch (_: Throwable) {
            // Best-effort; AdMob will still attempt its own WebView init.
        }
        super.onCreate(savedInstanceState)
    }
}
