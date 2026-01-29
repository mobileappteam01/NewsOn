import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage_service.dart';

/// Service to manage Google Mobile Ads
/// Fetches ad unit IDs from Firebase Realtime Database
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Cached ad unit IDs
  String? _androidBannerAdUnitId;
  String? _iosBannerAdUnitId;
  bool _isInitialized = false;

  // Test ad unit IDs (for development)
  static const String _testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Check if ads are initialized
  bool get isInitialized => _isInitialized;

  /// Get the appropriate banner ad unit ID based on platform
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _androidBannerAdUnitId ?? _testAndroidBannerAdUnitId;
    } else if (Platform.isIOS) {
      return _iosBannerAdUnitId ?? _testIosBannerAdUnitId;
    }
    return _testAndroidBannerAdUnitId;
  }

  /// Initialize the ad service
  /// Fetches ad unit IDs from Firebase Realtime Database
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('📢 AdService already initialized');
      return;
    }

    try {
      debugPrint('📢 Initializing AdService...');

      // Fetch Android ad unit ID
      _androidBannerAdUnitId = await _fetchAdUnitId('android_google_ads_key');
      if (_androidBannerAdUnitId != null &&
          _isValidBannerAdUnitId(_androidBannerAdUnitId)) {
        debugPrint('✅ Android Banner Ad Unit ID: $_androidBannerAdUnitId');
      } else {
        if (_androidBannerAdUnitId != null) {
          debugPrint(
            '⚠️ Android Ad Unit ID rejected: $_androidBannerAdUnitId is not a Banner ad unit. '
            'Please create a Banner ad unit in AdMob and update Firebase with the correct ID.',
          );
        } else {
          debugPrint(
            '⚠️ Android Banner Ad Unit ID not found in Firebase, using test ID',
          );
        }
        _androidBannerAdUnitId = null; // Will use test ID from getter
      }

      // Fetch iOS ad unit ID
      _iosBannerAdUnitId = await _fetchAdUnitId('ios_google_ads_key');
      if (_iosBannerAdUnitId != null &&
          _isValidBannerAdUnitId(_iosBannerAdUnitId)) {
        debugPrint('✅ iOS Banner Ad Unit ID: $_iosBannerAdUnitId');
      } else {
        debugPrint(
          '⚠️ iOS Banner Ad Unit ID invalid or not found, using test ID',
        );
        _iosBannerAdUnitId = null; // Will use test ID from getter
      }

      _isInitialized = true;
      debugPrint('✅ AdService initialized successfully');
      debugPrint('📢 Final Android Banner Ad Unit ID: ${bannerAdUnitId}');
    } catch (e) {
      debugPrint('❌ Error initializing AdService: $e');
      // Continue with test ad unit IDs
      _isInitialized = true;
    }
  }

  /// Known invalid ad unit IDs that are not Banner ads
  /// These are Native Advanced or other ad types that shouldn't be used for Banner ads
  static const Set<String> _invalidBannerAdUnitIds = {
    'ca-app-pub-6015484156094454/3610804804', // Native Advanced "Stay Wrogn"
    'ca-app-pub-6015484156094454/4019232448', // Interstitial "Full_Screen_Ads"
  };

  /// Validate if a string is a valid Banner Ad Unit ID
  /// Banner Ad Unit IDs use format: ca-app-pub-XXXXX/XXXXX (with slash)
  /// App IDs use format: ca-app-pub-XXXXX~XXXXX (with tilde)
  bool _isValidBannerAdUnitId(String? adUnitId) {
    if (adUnitId == null || adUnitId.isEmpty) {
      return false;
    }

    // Check if it's a known invalid ad unit ID (Native Advanced, Interstitial, etc.)
    if (_invalidBannerAdUnitIds.contains(adUnitId)) {
      debugPrint(
        '⚠️ Invalid: Ad Unit ID is a known non-Banner ad type (Native Advanced/Interstitial)',
      );
      return false;
    }

    // Check if it's an App ID (contains ~) - this is invalid for banner ads
    if (adUnitId.contains('~')) {
      debugPrint(
        '⚠️ Invalid: App ID detected (contains ~), not a Banner Ad Unit ID',
      );
      return false;
    }

    // Check if it's a valid Banner Ad Unit ID format (contains /)
    if (!adUnitId.contains('/')) {
      debugPrint('⚠️ Invalid: Ad Unit ID format incorrect (missing /)');
      return false;
    }

    // Check if it starts with ca-app-pub-
    if (!adUnitId.startsWith('ca-app-pub-')) {
      debugPrint('⚠️ Invalid: Ad Unit ID does not start with ca-app-pub-');
      return false;
    }

    return true;
  }

  /// Fetch ad unit ID from Firebase Realtime Database
  /// Also tries alternative keys for banner ad unit IDs
  Future<String?> _fetchAdUnitId(String key) async {
    try {
      final dbRef = _database.ref();

      // Try the primary key first
      var snapshot = await dbRef.child(key).get();
      String? adUnitId;

      if (snapshot.exists) {
        adUnitId = snapshot.value?.toString();
        debugPrint('📢 Fetched $key: $adUnitId');

        // Validate the ad unit ID
        if (_isValidBannerAdUnitId(adUnitId)) {
          // Cache the valid ad unit ID
          try {
            await StorageService.saveRealtimeDbCache(key, adUnitId);
          } catch (e) {
            debugPrint('⚠️ Error caching $key: $e');
          }
          return adUnitId;
        } else {
          debugPrint(
            '⚠️ Invalid Banner Ad Unit ID from $key, trying alternative keys...',
          );
        }
      }

      // Try alternative keys for banner ad unit IDs
      final alternativeKeys = [
        '${key}_banner', // e.g., android_google_ads_key_banner
        'android_banner_ad_unit_id', // For Android
        'ios_banner_ad_unit_id', // For iOS
        '${key.replaceAll('_key', '_banner_ad_unit_id')}', // Transform android_google_ads_key -> android_google_ads_banner_ad_unit_id
      ];

      for (final altKey in alternativeKeys) {
        try {
          snapshot = await dbRef.child(altKey).get();
          if (snapshot.exists) {
            adUnitId = snapshot.value?.toString();
            debugPrint('📢 Fetched alternative key $altKey: $adUnitId');

            if (_isValidBannerAdUnitId(adUnitId)) {
              debugPrint('✅ Valid Banner Ad Unit ID found from $altKey');
              // Cache the valid ad unit ID
              try {
                await StorageService.saveRealtimeDbCache(key, adUnitId);
              } catch (e) {
                debugPrint('⚠️ Error caching $key: $e');
              }
              return adUnitId;
            }
          }
        } catch (e) {
          // Continue to next alternative key
          continue;
        }
      }

      // If primary key exists but is invalid, try cache
      if (adUnitId != null) {
        debugPrint(
          '⚠️ Primary key $key returned invalid value, checking cache...',
        );
      } else {
        debugPrint('⚠️ $key not found in Realtime Database, checking cache...');
      }

      // Try to get from cache
      final cachedData = StorageService.getRealtimeDbCache(key);
      if (cachedData != null) {
        final cachedAdUnitId = cachedData.toString();
        debugPrint('📦 Using cached $key: $cachedAdUnitId');

        if (_isValidBannerAdUnitId(cachedAdUnitId)) {
          return cachedAdUnitId;
        } else {
          debugPrint(
            '⚠️ Cached value is also invalid, will use test ad unit ID',
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching $key: $e');

      // Try to get from cache
      try {
        final cachedData = StorageService.getRealtimeDbCache(key);
        if (cachedData != null) {
          final cachedAdUnitId = cachedData.toString();
          debugPrint('📦 Using cached $key: $cachedAdUnitId');

          if (_isValidBannerAdUnitId(cachedAdUnitId)) {
            return cachedAdUnitId;
          } else {
            debugPrint('⚠️ Cached value is invalid, will use test ad unit ID');
          }
        }
      } catch (cacheError) {
        debugPrint('⚠️ Error loading cached $key: $cacheError');
      }

      return null;
    }
  }

  /// Create a banner ad with the appropriate ad unit ID
  BannerAd createBannerAd({
    required BannerAdListener listener,
    AdSize size = AdSize.banner,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: listener,
    );
  }
}
