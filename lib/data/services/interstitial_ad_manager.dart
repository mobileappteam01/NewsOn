import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// Preloads and shows interstitials on natural breaks (e.g. leaving article).
class InterstitialAdManager {
  InterstitialAdManager._();

  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _interstitial;
  bool _isLoading = false;
  DateTime? _lastShownAt;
  int _articlesReadSinceLastShow = 0;
  int _sessionShowCount = 0;
  VoidCallback? _onDismissed;

  bool get isReady => _interstitial != null;

  void recordArticleEngaged() {
    _articlesReadSinceLastShow++;
  }

  Future<void> preload() async {
    final policy = AdService().policy;
    if (!policy.enabled || !policy.interstitialEnabled) return;
    if (_isLoading || _interstitial != null) return;

    await AdService().initialize();
    final ready = await AdService().ensureMobileAdsReady();
    if (!ready) {
      debugPrint('⚠️ Interstitial preload skipped — MobileAds not ready');
      return;
    }
    _isLoading = true;

    // Share the same WebView queue as banners so we don't starve JavascriptEngine.
    await AdService().runExclusiveBannerLoad(() async {
      await InterstitialAd.load(
        adUnitId: AdService().interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ Interstitial preloaded');
            _interstitial = ad;
            _isLoading = false;
            _attachCallbacks(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Interstitial load failed: ${error.message}');
            _interstitial = null;
            _isLoading = false;
          },
        ),
      );
    });
  }

  void _attachCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        final callback = _onDismissed;
        _onDismissed = null;
        callback?.call();
        unawaited(preload());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Interstitial show failed: ${error.message}');
        ad.dispose();
        _interstitial = null;
        unawaited(preload());
      },
    );
  }

  bool _canShow() {
    final policy = AdService().policy;
    if (!policy.enabled || !policy.interstitialEnabled) return false;
    if (_interstitial == null) return false;
    if (_sessionShowCount >= policy.interstitialMaxPerSession) return false;

    if (_lastShownAt != null) {
      final elapsed = DateTime.now().difference(_lastShownAt!);
      if (elapsed.inSeconds < policy.interstitialMinSeconds) {
        return false;
      }
    }

    if (_articlesReadSinceLastShow < policy.interstitialMinArticlesRead) {
      return false;
    }

    return true;
  }

  /// Returns true if an ad was shown. [onDismissed] runs after the user closes it.
  Future<bool> tryShowOnNaturalBreak({VoidCallback? onDismissed}) async {
    if (!_canShow()) {
      if (_interstitial == null) unawaited(preload());
      return false;
    }

    final ad = _interstitial!;
    _interstitial = null;
    _lastShownAt = DateTime.now();
    _articlesReadSinceLastShow = 0;
    _sessionShowCount++;
    _onDismissed = onDismissed;

    ad.show();
    debugPrint('📢 Interstitial shown (session $_sessionShowCount)');
    return true;
  }

  void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}
