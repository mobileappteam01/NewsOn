import 'dart:async';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/ad_policy.dart';
import '../../core/widgets/live_banner_ad_cache.dart';
import 'ad_network_diagnostics.dart';

/// Loads AdMob unit IDs from Firebase and picks the correct format per placement.
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() => _instance;

  AdService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isInitialized = false;
  bool _mobileAdsReady = false;
  bool _mobileAdsInitializing = false;
  Completer<bool>? _mobileAdsCompleter;
  Completer<void>? _initCompleter;
  AdPolicy _policy = AdPolicy.defaults;
  bool _productionIdsMisconfigured = false;

  /// After live units return "publisher data not found", use Google sample
  /// units for the rest of this process so QA can verify placements.
  bool _sessionForceTestUnits = false;

  /// `flutter run --release --dart-define=FORCE_TEST_ADS=true`
  static const bool _forceTestAdsEnv =
      bool.fromEnvironment('FORCE_TEST_ADS', defaultValue: false);

  /// Serializes BannerAd.load() calls. Parallel loads on Xiaomi/OEM devices
  /// overwhelm the WebView process and surface as "Unable to obtain a
  /// JavascriptEngine" (error code 0).
  Future<void> _bannerLoadQueue = Future.value();
  static const Duration _postSdkWarmup = Duration(milliseconds: 800);
  static const Duration _betweenBannerLoads = Duration(milliseconds: 350);

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

  /// Medium unit IDs that are not real AdMob units (cause code 3 /
  /// "Publisher data not found"). Always fall back to Banner instead.
  static const Set<String> _invalidMediumUnitIds = {
    'ca-app-pub-6015484156094454/2875777054',
  };

  bool get isInitialized => _isInitialized;
  bool get isMobileAdsReady => _mobileAdsReady;
  AdPolicy get policy => _policy;

  /// Test-only: override policy without Firebase.
  @visibleForTesting
  void applyPolicyForTest(AdPolicy policy) {
    _policy = policy;
  }
  bool get productionIdsMisconfigured => _productionIdsMisconfigured;

  /// Test units when Firebase / env / debug / session publisher-error fallback.
  bool get shouldUseTestAdUnits =>
      _forceTestAdsEnv ||
      _policy.useTestAds ||
      _productionIdsMisconfigured ||
      _sessionForceTestUnits ||
      kDebugMode;

  static bool isPublisherSetupError(LoadAdError error) {
    final msg = error.message.toLowerCase();
    // "No fill" alone is normal inventory emptiness — do not force test ads.
    // "Publisher data not found" means the app/unit is not serving in AdMob.
    return msg.contains('publisher data not found');
  }

  /// Call from banner/inline failure handlers. Returns true if the caller
  /// should immediately retry (now on Google test units).
  Future<bool> handleLoadFailure(LoadAdError error) async {
    if (_sessionForceTestUnits || _policy.useTestAds) return false;
    if (!isPublisherSetupError(error)) return false;

    _sessionForceTestUnits = true;
    debugPrint(
      '⚠️ Live AdMob units returned "${error.message}" (code ${error.code}).\n'
      '   Switching this session to Google TEST ad units so placements can be verified.\n'
      '   Fix AdMob (app approved, billing, Policy center) and/or set '
      'ads_config.use_test_ads=true in Firebase RTDB for intentional QA.\n'
      '   See https://support.google.com/admob/answer/9905175#9',
    );
    await _applyRequestConfiguration();
    return true;
  }

  String? _sanitizeMediumId(String? id) {
    final cleaned = _cleanId(id);
    if (cleaned == null) return null;
    if (_invalidMediumUnitIds.contains(cleaned)) return null;
    return cleaned;
  }

  String? get _effectiveAndroidMediumId =>
      _sanitizeMediumId(_androidMediumRectangleId);

  String? get _effectiveIosMediumId =>
      _sanitizeMediumId(_iosMediumRectangleId);

  /// Wait until [MobileAds.initialize] finishes (or [timeout]).
  Future<bool> ensureMobileAdsReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_mobileAdsReady) return true;

    // Kick off full AdService init if nothing has started yet.
    // Avoid re-entering [initialize] while it is already running (deadlock).
    if (!_isInitialized && _initCompleter == null) {
      await initialize();
      if (_mobileAdsReady) return true;
    }

    _mobileAdsCompleter ??= Completer<bool>();
    if (_mobileAdsCompleter!.isCompleted) return _mobileAdsReady;

    // Ensure the SDK init future is actually running.
    unawaited(_initializeMobileAdsSdk());

    try {
      return await _mobileAdsCompleter!.future.timeout(timeout);
    } catch (_) {
      return _mobileAdsReady;
    }
  }

  Future<void> _applyRequestConfiguration() async {
    // Always register known QA devices so AdMob can serve test ads when
    // requested; does not force test creatives by itself.
    const testDevices = [
      '6E221DF684D0B597923A949ED82C2D7D',
      '656FE85C8D08386073977B1F62D93163',
    ];

    if (shouldUseTestAdUnits) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: testDevices,
          tagForChildDirectedTreatment:
              TagForChildDirectedTreatment.unspecified,
        ),
      );
      debugPrint('📢 AdMob: test mode (test units or test device routing)');
    } else {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDevices),
      );
      debugPrint('📢 AdMob: live ad units from Firebase');
    }
  }

  /// Human-readable hint for common AdMob load failures (esp. code 3).
  static String describeLoadError(LoadAdError error) {
    final code = error.code;
    final message = error.message;
    final lower = message.toLowerCase();
    if (lower.contains('publisher data not found')) {
      return 'AdMob publisher data not found (code $code). '
          'App/ad-unit setup issue — not an app crash. Check: app approved, '
          'billing complete, Policy center clean, correct app ID. '
          'See https://support.google.com/admob/answer/9905175#9';
    }
    if (code == 3 || lower.contains('no fill')) {
      return 'AdMob no fill (code $code): $message. '
          'Often temporary inventory emptiness on live units. '
          'For QA use: flutter run --release --dart-define=FORCE_TEST_ADS=true '
          'or set ads_config.use_test_ads=true in Firebase RTDB.';
    }
    if (message.contains('JavascriptEngine')) {
      return 'WebView/JavascriptEngine failed — check Private DNS / AdGuard / VPN.';
    }
    return message;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      // Hot restart / late callers: scrub phantom medium IDs even if init
      // already completed with a stale Firebase value.
      _scrubInvalidMediumIds();
      if (!_mobileAdsReady && _mobileAdsCompleter != null) {
        await ensureMobileAdsReady();
      }
      return;
    }

    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();

    try {
      debugPrint('📢 Initializing AdService...');

      // Start MobileAds SDK early — must finish before any BannerAd.load().
      unawaited(_initializeMobileAdsSdk());

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
      _scrubInvalidMediumIds();

      final policySnapshot = await ref.child('ads_config').get();
      if (policySnapshot.value is Map) {
        _policy = AdPolicy.fromMap(
          Map<dynamic, dynamic>.from(policySnapshot.value as Map),
        );
      }

      // Detail-carousel toggles live in Firebase Remote Config (override RTDB).
      _applyDetailCarouselFromRemoteConfig();

      _productionIdsMisconfigured = _detectMisconfiguredIds();

      await _applyRequestConfiguration();

      // Prefer waiting for the SDK; ads will no-op cleanly if it never comes up.
      if (!_mobileAdsReady && _mobileAdsCompleter != null) {
        try {
          await _mobileAdsCompleter!.future.timeout(
            const Duration(seconds: 15),
          );
        } catch (_) {}
      }

      // Surface Private DNS / AdGuard blocks early (saves rebuild chasing).
      unawaited(AdNetworkDiagnostics.checkAdsReachable());

      debugPrint('✅ AdService initialized');
      debugPrint('📢 Ads enabled: ${_policy.enabled}');
      debugPrint('📢 MobileAds ready: $_mobileAdsReady');
      debugPrint('📢 Using test ad units: $shouldUseTestAdUnits');
      debugPrint('📢 Inline interval: ${_policy.inlineInterval}');
      debugPrint(
        '📢 Home section banner: ${_policy.homeSectionBannerEnabled}',
      );
      debugPrint(
        '📢 Detail carousel ads: ${_policy.detailCarouselAdsEnabled} '
        '(every ${_policy.detailCarouselAdInterval})',
      );
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
        if (_forceTestAdsEnv) {
          debugPrint('ℹ️ FORCE_TEST_ADS dart-define is on — Google test units');
        }
      } else {
        debugPrint('📢 Production banner: $bannerAdUnitId');
        debugPrint(
          '📢 Inline feed: $inlineFeedAdUnitId '
          '(${hasDedicatedMediumUnit ? 'medium rectangle' : 'large banner fallback'})',
        );
        debugPrint('📢 Production interstitial: $interstitialAdUnitId');
      }

      _isInitialized = true;
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    } catch (e) {
      debugPrint('❌ AdService init error: $e');
      _isInitialized = true;
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    }
  }

  Future<void> _initializeMobileAdsSdk() async {
    if (_mobileAdsReady) return;
    if (_mobileAdsInitializing) {
      _mobileAdsCompleter ??= Completer<bool>();
      await _mobileAdsCompleter!.future;
      return;
    }

    _mobileAdsInitializing = true;
    _mobileAdsCompleter ??= Completer<bool>();

    try {
      debugPrint('📢 MobileAds.initialize() starting...');
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 25),
      );
      // Give the WebView / JavascriptEngine process time to come up before
      // the first BannerAd.load() — critical on cold start / release.
      await Future<void>.delayed(_postSdkWarmup);
      _mobileAdsReady = true;
      debugPrint('✅ MobileAds.initialize() completed');
      if (!(_mobileAdsCompleter?.isCompleted ?? true)) {
        _mobileAdsCompleter!.complete(true);
      }
    } catch (e) {
      debugPrint('❌ MobileAds.initialize() failed: $e');
      _mobileAdsReady = false;
      if (!(_mobileAdsCompleter?.isCompleted ?? true)) {
        _mobileAdsCompleter!.complete(false);
      }
    } finally {
      _mobileAdsInitializing = false;
    }
  }

  /// Runs [load] one-at-a-time so inline + anchor + interstitial don't race
  /// the shared WebView process.
  Future<T> runExclusiveBannerLoad<T>(Future<T> Function() load) {
    final previous = _bannerLoadQueue;
    final gate = Completer<void>();
    _bannerLoadQueue = gate.future;

    return previous.then((_) async {
      try {
        return await load();
      } finally {
        await Future<void>.delayed(_betweenBannerLoads);
        if (!gate.isCompleted) gate.complete();
      }
    });
  }

  static String? _cleanId(String? id) {
    if (id == null) return null;
    final trimmed = id.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _scrubInvalidMediumIds() {
    if (_androidMediumRectangleId != null &&
        _sanitizeMediumId(_androidMediumRectangleId) == null) {
      debugPrint(
        '⚠️ android_medium_ad_id $_androidMediumRectangleId is not a valid '
        'AdMob unit — ignoring. In-feed ads use Banner '
        '(…/3897012392) + largeBanner. Create a Medium rectangle unit in '
        'AdMob, then update Firebase.',
      );
      _androidMediumRectangleId = null;
    }
    if (_iosMediumRectangleId != null &&
        _sanitizeMediumId(_iosMediumRectangleId) == null) {
      debugPrint(
        '⚠️ ios_medium_ad_id $_iosMediumRectangleId is not a valid '
        'AdMob unit — ignoring.',
      );
      _iosMediumRectangleId = null;
    }
  }

  /// Prefer Firebase Remote Config for detail-carousel ad flags.
  void _applyDetailCarouselFromRemoteConfig() {
    try {
      final rc = FirebaseRemoteConfig.instance;
      var enabled = _policy.detailCarouselAdsEnabled;
      try {
        enabled = rc.getBool('detail_carousel_ads_enabled');
      } catch (_) {
        final raw =
            rc.getString('detail_carousel_ads_enabled').trim().toLowerCase();
        if (raw == 'true' || raw == '1') enabled = true;
        if (raw == 'false' || raw == '0') enabled = false;
      }

      var interval = _policy.detailCarouselAdInterval;
      try {
        final v = rc.getInt('detail_carousel_ad_interval');
        if (v > 0) interval = v;
      } catch (_) {
        interval = int.tryParse(rc.getString('detail_carousel_ad_interval')) ??
            interval;
      }

      _policy = _policy.copyWith(
        detailCarouselAdsEnabled: enabled,
        detailCarouselAdInterval: interval.clamp(3, 8),
      );
      debugPrint(
        '📢 Remote Config detail carousel: enabled=$enabled interval=$interval',
      );
    } catch (e) {
      debugPrint('⚠️ Remote Config detail carousel unavailable: $e');
    }
  }

  bool _detectMisconfiguredIds() {
    // Banner + medium may share one Banner-format unit (common when only
    // Banner + Interstitial exist in AdMob). Only flag cross-format clashes.
    if (Platform.isAndroid) {
      return _idsAreSame(_androidBannerId, _androidInterstitialId) ||
          _idsAreSame(_effectiveAndroidMediumId, _androidInterstitialId);
    }
    return _idsAreSame(_iosBannerId, _iosInterstitialId) ||
        _idsAreSame(_effectiveIosMediumId, _iosInterstitialId);
  }

  static bool _idsAreSame(String? a, String? b) {
    if (a == null || b == null) return false;
    return a == b;
  }

  /// True when Firebase has a usable medium ID distinct from the banner unit.
  bool get hasDedicatedMediumUnit {
    if (shouldUseTestAdUnits) return true;
    if (Platform.isAndroid) {
      final medium = _effectiveAndroidMediumId;
      return medium != null && !_idsAreSame(medium, _androidBannerId);
    }
    final medium = _effectiveIosMediumId;
    return medium != null && !_idsAreSame(medium, _iosBannerId);
  }

  /// In-feed: medium rectangle only with a real dedicated unit; otherwise
  /// large banner on the Banner ad unit (matches your AdMob dashboard).
  AdSize get inlineFeedAdSize =>
      hasDedicatedMediumUnit ? AdSize.mediumRectangle : AdSize.largeBanner;

  /// Width-aware size for feed / carousel slots so 320px creatives are not
  /// requested inside padded lists on ~360dp phones (common load/clip failure).
  AdSize resolveInlineFeedAdSize(int maxWidthPx) {
    final width = maxWidthPx.clamp(160, 1200);
    if (hasDedicatedMediumUnit && width >= 300) {
      return AdSize.mediumRectangle;
    }
    // Adaptive inline banner on the Banner unit — fills available width.
    return AdSize.getInlineAdaptiveBannerAdSize(width, 120);
  }

  String get inlineFeedAdUnitId {
    if (hasDedicatedMediumUnit) return mediumRectangleAdUnitId;
    return bannerAdUnitId;
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
          return _effectiveAndroidMediumId ??
              _androidBannerId ??
              _testAndroidMedium;
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
        return _effectiveIosMediumId ?? _iosBannerId ?? _testIosMedium;
      case AdFormat.interstitial:
        return _iosInterstitialId ?? _testIosInterstitial;
    }
  }

  BannerAd createBannerAd({
    required BannerAdListener listener,
    AdSize size = AdSize.banner,
    String? adUnitId,
    bool anchored = false,
    bool inlineFeed = false,
    /// Logical pixels available for the creative (after list/slot padding).
    int? maxContentWidth,
  }) {
    // Always sanitize — never request a known-invalid medium unit.
    var resolvedSize = size;
    var unitId = adUnitId;
    if (inlineFeed) {
      resolvedSize = maxContentWidth != null && maxContentWidth > 0
          ? resolveInlineFeedAdSize(maxContentWidth)
          : inlineFeedAdSize;
      unitId = inlineFeedAdUnitId;
    } else if (anchored) {
      unitId ??= anchoredBannerAdUnitId;
    } else if (unitId == null) {
      final isMedium = size.width == AdSize.mediumRectangle.width &&
          size.height == AdSize.mediumRectangle.height;
      if (isMedium) {
        if (hasDedicatedMediumUnit) {
          unitId = mediumRectangleAdUnitId;
        } else {
          // Banner-format unit cannot serve 300x250 — remap size + unit.
          resolvedSize = AdSize.largeBanner;
          unitId = bannerAdUnitId;
        }
      } else {
        unitId = bannerAdUnitId;
      }
    }

    if (_invalidMediumUnitIds.contains(unitId)) {
      debugPrint(
        '⚠️ Refusing invalid medium unit $unitId — using Banner instead',
      );
      unitId = bannerAdUnitId;
      resolvedSize = maxContentWidth != null && maxContentWidth > 0
          ? resolveInlineFeedAdSize(maxContentWidth)
          : AdSize.largeBanner;
    }

    debugPrint(
      '📢 Loading ${anchored ? 'anchored' : '${resolvedSize.width}x${resolvedSize.height}'} '
      'ad: $unitId${inlineFeed ? ' (inline feed)' : ''}',
    );

    return BannerAd(
      adUnitId: unitId as String,
      request: const AdRequest(),
      size: resolvedSize,
      listener: listener,
    );
  }

  static Future<AdSize?> anchoredAdaptiveSize(int widthPx) async {
    if (widthPx <= 0) return AdSize.banner;
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      widthPx.truncate(),
    );
  }

  /// Warm inline feed slots before the user scrolls to them.
  Future<void> preloadInlineFeedAds({
    required int slotCount,
    required int contentWidthPx,
    String cacheKeyPrefix = 'inline_feed_ad',
  }) async {
    if (!policy.enabled || slotCount <= 0) return;
    await initialize();
    if (!await ensureMobileAdsReady()) return;

    for (var slot = 0; slot < slotCount; slot++) {
      final cacheId = '${cacheKeyPrefix}_$slot';
      if (LiveBannerAdCache.instance.contains(cacheId)) continue;

      await runExclusiveBannerLoad(() async {
        final completer = Completer<void>();
        final banner = createBannerAd(
          inlineFeed: true,
          maxContentWidth: contentWidthPx,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              final loaded = ad as BannerAd;
              LiveBannerAdCache.instance.store(
                cacheId,
                loaded,
                loaded.size,
              );
              debugPrint('✅ Preloaded inline feed ad $cacheId');
              completer.complete();
            },
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              debugPrint(
                '⚠️ Preload inline $cacheId failed: ${error.message}',
              );
              completer.complete();
            },
          ),
        );
        banner.load();
        await completer.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
      });
    }
  }
}

enum AdFormat { banner, anchored, mediumRectangle, interstitial }
