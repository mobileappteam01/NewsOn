import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/ad_policy.dart';

/// Loads AdMob unit IDs from Firebase and picks the correct format per placement.
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() => _instance;

  AdService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isInitialized = false;
  AdPolicy _policy = AdPolicy.defaults;
  bool _productionIdsMisconfigured = false;

  /// Google official test units — always work in development.
  /// https://developers.google.com/admob/android/test-ads
  static const String _testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidAnchored =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testAndroidMedium =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosAnchored =
      'ca-app-pub-3940256099942544/2435281174';
  static const String _testIosMedium = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  String? _androidBannerId;
  String? _androidMediumRectangleId;
  String? _androidInterstitialId;

  String? _iosBannerId;
  String? _iosMediumRectangleId;
  String? _iosInterstitialId;

  bool get isInitialized => _isInitialized;
  AdPolicy get policy => _policy;
  bool get productionIdsMisconfigured => _productionIdsMisconfigured;

  /// Test units only when Firebase says so, or production IDs are invalid.
  /// Debug/profile builds still use live Firebase IDs when configured correctly.
  bool get shouldUseTestAdUnits =>
      _policy.useTestAds || _productionIdsMisconfigured;

  Future<void> _applyRequestConfiguration() async {
    if (shouldUseTestAdUnits) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: const [
            '6E221DF684D0B597923A949ED82C2D7D',
          ],
          tagForChildDirectedTreatment:
              TagForChildDirectedTreatment.unspecified,
        ),
      );
      debugPrint('📢 AdMob: test mode (test units or test device routing)');
    } else {
      // Do not register this device as a test device — live units serve real ads.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(),
      );
      debugPrint('📢 AdMob: live ad units from Firebase');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('📢 Initializing AdService...');

      final ref = _database.ref();

      _androidBannerId = _cleanId(
        (await ref.child('android_banner_ad_id').get()).value?.toString(),
      );
      _androidMediumRectangleId = _cleanId(
        (await ref.child('android_medium_ad_id').get()).value?.toString(),
      );
      _androidInterstitialId = _cleanId(
        (await ref.child('android_interstitial_ad_id').get()).value?.toString(),
      );

      _iosBannerId = _cleanId(
          (await ref.child('ios_banner_ad_id').get()).value?.toString());
      _iosMediumRectangleId = _cleanId(
        (await ref.child('ios_medium_ad_id').get()).value?.toString(),
      );
      _iosInterstitialId = _cleanId(
        (await ref.child('ios_interstitial_ad_id').get()).value?.toString(),
      );

      final policySnapshot = await ref.child('ads_config').get();
      if (policySnapshot.value is Map) {
        _policy = AdPolicy.fromMap(
          Map<dynamic, dynamic>.from(policySnapshot.value as Map),
        );
      }

      _productionIdsMisconfigured = _detectMisconfiguredIds();

      await _applyRequestConfiguration();

      debugPrint('✅ AdService initialized');
      debugPrint('📢 Ads enabled: ${_policy.enabled}');
      debugPrint('📢 Using test ad units: $shouldUseTestAdUnits');
      if (_productionIdsMisconfigured) {
        debugPrint(
          '⚠️ Firebase ad IDs are identical for multiple formats — using '
          'Google test units until you set separate banner, medium, and '
          'interstitial IDs in Realtime Database. See docs/ADS_STRATEGY.md',
        );
      }
      if (_policy.useTestAds) {
        debugPrint(
          'ℹ️ ads_config.use_test_ads is true — set to false for live ads',
        );
      }
      if (shouldUseTestAdUnits) {
        debugPrint('📢 Banner unit: $bannerAdUnitId');
        debugPrint('📢 Medium unit: $mediumRectangleAdUnitId');
        debugPrint('📢 Interstitial unit: $interstitialAdUnitId');
      } else {
        debugPrint('📢 Production banner: $bannerAdUnitId');
        debugPrint('📢 Production medium: $mediumRectangleAdUnitId');
        debugPrint('📢 Production interstitial: $interstitialAdUnitId');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ AdService init error: $e');
      _isInitialized = true;
    }
  }

  static String? _cleanId(String? id) {
    if (id == null) return null;
    final trimmed = id.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _detectMisconfiguredIds() {
    if (Platform.isAndroid) {
      return _idsAreSame(_androidBannerId, _androidMediumRectangleId) ||
          _idsAreSame(_androidBannerId, _androidInterstitialId) ||
          _idsAreSame(_androidMediumRectangleId, _androidInterstitialId);
    }
    return _idsAreSame(_iosBannerId, _iosMediumRectangleId) ||
        _idsAreSame(_iosBannerId, _iosInterstitialId) ||
        _idsAreSame(_iosMediumRectangleId, _iosInterstitialId);
  }

  static bool _idsAreSame(String? a, String? b) {
    if (a == null || b == null) return false;
    return a == b;
  }

  String get bannerAdUnitId => _unitForFormat(AdFormat.banner);

  String get anchoredBannerAdUnitId => _unitForFormat(AdFormat.anchored);

  String get mediumRectangleAdUnitId =>
      _unitForFormat(AdFormat.mediumRectangle);

  String get interstitialAdUnitId => _unitForFormat(AdFormat.interstitial);

  String _unitForFormat(AdFormat format) {
    if (shouldUseTestAdUnits) {
      if (Platform.isAndroid) {
        switch (format) {
          case AdFormat.banner:
            return _testAndroidBanner;
          case AdFormat.anchored:
            return _testAndroidAnchored;
          case AdFormat.mediumRectangle:
            return _testAndroidMedium;
          case AdFormat.interstitial:
            return _testAndroidInterstitial;
        }
      }
      switch (format) {
        case AdFormat.banner:
          return _testIosBanner;
        case AdFormat.anchored:
          return _testIosAnchored;
        case AdFormat.mediumRectangle:
          return _testIosMedium;
        case AdFormat.interstitial:
          return _testIosInterstitial;
      }
    }

    if (Platform.isAndroid) {
      switch (format) {
        case AdFormat.banner:
          return _androidBannerId ?? _testAndroidBanner;
        case AdFormat.anchored:
          return _androidBannerId ?? _testAndroidAnchored;
        case AdFormat.mediumRectangle:
          return _androidMediumRectangleId ?? _testAndroidMedium;
        case AdFormat.interstitial:
          return _androidInterstitialId ?? _testAndroidInterstitial;
      }
    }

    switch (format) {
      case AdFormat.banner:
        return _iosBannerId ?? _testIosBanner;
      case AdFormat.anchored:
        return _iosBannerId ?? _testIosAnchored;
      case AdFormat.mediumRectangle:
        return _iosMediumRectangleId ?? _testIosMedium;
      case AdFormat.interstitial:
        return _iosInterstitialId ?? _testIosInterstitial;
    }
  }

  BannerAd createBannerAd({
    required BannerAdListener listener,
    AdSize size = AdSize.banner,
    String? adUnitId,
    bool anchored = false,
  }) {
    final unitId = adUnitId ??
        (anchored
            ? anchoredBannerAdUnitId
            : size == AdSize.mediumRectangle
                ? mediumRectangleAdUnitId
                : bannerAdUnitId);

    if (kDebugMode) {
      debugPrint(
          '📢 Loading ${anchored ? 'anchored' : size.toString()} ad: $unitId');
    }

    return BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: size,
      listener: listener,
    );
  }

  static Future<AdSize?> anchoredAdaptiveSize(int widthPx) async {
    if (widthPx <= 0) return AdSize.banner;
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      widthPx.truncate(),
    );
  }
}

enum AdFormat { banner, anchored, mediumRectangle, interstitial }
