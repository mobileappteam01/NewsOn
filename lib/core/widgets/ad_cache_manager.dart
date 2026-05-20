import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';

class AdCacheManager {
  static final AdCacheManager instance = AdCacheManager._();

  AdCacheManager._();

  final List<BannerAd> _mediumAds = [];

  bool _isLoading = false;

  Future<void> preloadMediumAds() async {
    if (_isLoading) return;

    if (_mediumAds.length >= 3) return;

    _isLoading = true;

    for (int i = 0; i < 3; i++) {
      final ad = AdService().createBannerAd(
        size: AdSize.mediumRectangle,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint("✅ Medium ad loaded");
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint("❌ Medium ad failed: ${error.message}");
            ad.dispose();
          },
        ),
      );

      await ad.load();

      _mediumAds.add(ad);
    }

    _isLoading = false;
  }

  BannerAd? getMediumAd(int index) {
    if (_mediumAds.isEmpty) return null;

    return _mediumAds[index % _mediumAds.length];
  }
}
