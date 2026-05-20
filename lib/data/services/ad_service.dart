import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() => _instance;

  AdService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isInitialized = false;

  /// =========================
  /// DEFAULT FALLBACK IDS
  /// =========================

  static const String _defaultAndroidBannerId =
      'ca-app-pub-6015484156094454/2875777054';

  static const String _defaultAndroidMediumRectangleId =
      'ca-app-pub-6015484156094454/2875777054';

  static const String _defaultAndroidInterstitialId =
      'ca-app-pub-6015484156094454/2875777054';

  static const String _defaultIosBannerId =
      'ca-app-pub-6015484156094454/2875777054';

  static const String _defaultIosMediumRectangleId =
      'ca-app-pub-6015484156094454/2875777054';

  static const String _defaultIosInterstitialId =
      'ca-app-pub-6015484156094454/2875777054';

  /// =========================
  /// DYNAMIC IDS FROM FIREBASE
  /// =========================

  String? _androidBannerId;
  String? _androidMediumRectangleId;
  String? _androidInterstitialId;

  String? _iosBannerId;
  String? _iosMediumRectangleId;
  String? _iosInterstitialId;

  bool get isInitialized => _isInitialized;

  /// =========================
  /// INITIALIZE
  /// =========================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('📢 Initializing AdService...');

      final ref = _database.ref();

      /// ANDROID IDS

      _androidBannerId =
          (await ref.child('android_banner_ad_id').get()).value?.toString();

      _androidMediumRectangleId =
          (await ref.child('android_medium_ad_id').get()).value?.toString();

      _androidInterstitialId =
          (await ref.child('android_interstitial_ad_id').get())
              .value
              ?.toString();

      /// IOS IDS

      _iosBannerId =
          (await ref.child('ios_banner_ad_id').get()).value?.toString();

      _iosMediumRectangleId =
          (await ref.child('ios_medium_ad_id').get()).value?.toString();

      _iosInterstitialId =
          (await ref.child('ios_interstitial_ad_id').get()).value?.toString();

      debugPrint('✅ AdService initialized');

      debugPrint('📢 Android Banner: $_androidBannerId');
      debugPrint('📢 iOS Banner: $_iosBannerId');

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ AdService init error: $e');
    }
  }

  /// =========================
  /// GETTERS
  /// =========================

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _androidBannerId ?? _defaultAndroidBannerId;
    } else {
      return _iosBannerId ?? _defaultIosBannerId;
    }
  }

  String get mediumRectangleAdUnitId {
    if (Platform.isAndroid) {
      return _androidMediumRectangleId ?? _defaultAndroidMediumRectangleId;
    } else {
      return _iosMediumRectangleId ?? _defaultIosMediumRectangleId;
    }
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _androidInterstitialId ?? _defaultAndroidInterstitialId;
    } else {
      return _iosInterstitialId ?? _defaultIosInterstitialId;
    }
  }

  /// =========================
  /// CREATE BANNER
  /// =========================

  BannerAd createBannerAd({
    required BannerAdListener listener,
    AdSize size = AdSize.banner,
  }) {
    final adUnitId = size == AdSize.mediumRectangle
        ? mediumRectangleAdUnitId
        : bannerAdUnitId;

    debugPrint('📢 Creating Banner Ad: $adUnitId');

    return BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: listener,
    );
  }
}
