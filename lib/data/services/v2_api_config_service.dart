import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/v2_api_config.dart';
import 'storage_service.dart';

typedef V2ApiConfigFetcher = Future<V2ApiConfig?> Function();
typedef V2ApiConfigCacheReader = V2ApiConfig? Function();
typedef V2ApiConfigCacheWriter = Future<void> Function(V2ApiConfig config);

/// Loads and caches the isolated V2 API host from Firestore `apiEndPoints/v2`.
///
/// Does not read or write V1 `ipAddress` / V1 endpoint modules.
///
/// Call [ensureReady] (or [ready]) before any V2 host request so startup
/// ordering cannot race ahead of Firebase/cache hydration.
class V2ApiConfigService {
  V2ApiConfigService({
    FirebaseFirestore? firestore,
    V2ApiConfigFetcher? fetcher,
    V2ApiConfigCacheReader? cacheReader,
    V2ApiConfigCacheWriter? cacheWriter,
    String? dartDefineOverride,
  })  : _firestore = firestore,
        _fetcher = fetcher,
        _cacheReader = cacheReader,
        _cacheWriter = cacheWriter,
        _dartDefineOverride = dartDefineOverride;

  static final V2ApiConfigService instance = V2ApiConfigService();

  /// Firestore document id under [apiEndPoints] that holds V2 host fields.
  static const firestoreModule = 'v2';

  FirebaseFirestore? _firestore;
  final V2ApiConfigFetcher? _fetcher;
  final V2ApiConfigCacheReader? _cacheReader;
  final V2ApiConfigCacheWriter? _cacheWriter;
  final String? _dartDefineOverride;

  V2ApiConfig? _config;
  bool _initialized = false;

  /// Single shared init future — concurrent callers await the same work.
  /// Kept after completion so later awaiters resolve immediately (no re-fetch).
  Future<void>? _readyFuture;

  V2ApiConfig? get config => _config;
  bool get isInitialized => _initialized;
  bool get isReady => _initialized;
  bool get isUsable => baseUrlIfEnabled != null;

  /// Shared readiness future. Completes when initialize finished (success or soft-fail).
  /// Does **not** imply [isUsable] — call [requireBaseUrl] / [requireReadyBaseUrl] for that.
  Future<void> get ready => ensureReady();

  /// Usable V2 origin when loaded and enabled; otherwise null (do not use for V2 features).
  String? get baseUrlIfEnabled {
    final c = _config;
    if (c == null || !c.isUsable) return null;
    return c.baseUrl;
  }

  /// Required V2 origin for V2 feature traffic. Never returns the V1 base URL.
  /// Prefer [requireReadyBaseUrl] from async callers so startup races wait first.
  String requireBaseUrl() {
    final url = baseUrlIfEnabled;
    if (url != null) return url;
    throw V2ApiConfigException(
      'V2 API configuration is missing or disabled. '
      'Create Firestore document apiEndPoints/$firestoreModule with '
      'fields baseUrl (https URL) and enabled=true. '
      'V2 traffic will not fall back to the V1 API host.',
    );
  }

  /// Awaits [ensureReady], then returns a usable V2 base URL or throws [V2ApiConfigException].
  Future<String> requireReadyBaseUrl() async {
    await ensureReady();
    return requireBaseUrl();
  }

  /// Optional compile-time override (tests / local staging), mirrors V1 NEWSON_API_BASE_URL pattern.
  static String? get _envOverride {
    const raw = String.fromEnvironment('NEWSON_V2_API_BASE_URL');
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Ensures V2 config load has completed exactly once (Firebase and/or Hive cache).
  ///
  /// Safe to call from many V2 features concurrently — they share one future.
  /// Does not throw when config is missing/disabled; callers use [requireBaseUrl].
  Future<void> ensureReady() {
    if (_initialized) return Future<void>.value();
    return _readyFuture ??= _doInitialize();
  }

  /// Alias for [ensureReady] (kept for existing ApiService / bootstrap call sites).
  Future<void> initialize() => ensureReady();

  Future<void> _doInitialize() async {
    try {
      final fromDefine = (_dartDefineOverride ?? _envOverride)?.trim();
      if (fromDefine != null && fromDefine.isNotEmpty) {
        _config = V2ApiConfig(baseUrl: fromDefine, enabled: true);
        _initialized = true;
        debugPrint(
          '✅ V2 API base from NEWSON_V2_API_BASE_URL: ${_config!.baseUrl}',
        );
        return;
      }

      _hydrateFromCache();

      try {
        final remote = await (_fetcher ?? _fetchFromFirestore)().timeout(
          const Duration(seconds: 10),
        );
        if (remote != null && remote.baseUrl.isNotEmpty) {
          _config = remote;
          await _persist(remote);
          debugPrint(
            '✅ V2 API config loaded (enabled=${remote.enabled}, base=${remote.baseUrl})',
          );
        } else if (_config == null) {
          debugPrint('⚠️ V2 API config document missing or empty');
        }
      } catch (e) {
        debugPrint('⚠️ V2 API config fetch failed (using cache if any): $e');
        if (_config == null) {
          _hydrateFromCache();
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ V2 API config initialize soft-fail: $e');
      _hydrateFromCache();
      _initialized = true;
    }
  }

  Future<V2ApiConfig?> _fetchFromFirestore() async {
    final firestore = _firestore ??= FirebaseFirestore.instance;
    final snap = await firestore
        .collection('apiEndPoints')
        .doc(firestoreModule)
        .get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null || data.isEmpty) return null;
    return V2ApiConfig.fromFirestoreMap(Map<String, dynamic>.from(data));
  }

  void _hydrateFromCache() {
    try {
      final reader = _cacheReader ?? _readDefaultCache;
      final cached = reader();
      if (cached != null && cached.baseUrl.isNotEmpty) {
        _config = cached;
        debugPrint(
          '📦 Hydrated V2 API config from cache (enabled=${cached.enabled})',
        );
      }
    } catch (e) {
      debugPrint('⚠️ V2 API config cache hydrate failed: $e');
    }
  }

  Future<void> _persist(V2ApiConfig config) async {
    try {
      final writer = _cacheWriter ?? _writeDefaultCache;
      await writer(config);
    } catch (e) {
      debugPrint('⚠️ V2 API config cache write failed: $e');
    }
  }

  static V2ApiConfig? _readDefaultCache() {
    try {
      final cached = StorageService.getV2ApiConfigCache();
      if (cached == null || cached.isEmpty) return null;
      return V2ApiConfig.fromCacheJson(cached);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDefaultCache(V2ApiConfig config) async {
    await StorageService.saveV2ApiConfigCache(config.toCacheJson());
  }

  /// Test / recovery: clear in-memory state (does not wipe Hive).
  @visibleForTesting
  void resetForTest() {
    _config = null;
    _initialized = false;
    _readyFuture = null;
  }

  /// Test helper to inject a resolved config without Firestore.
  @visibleForTesting
  void debugSetConfig(V2ApiConfig? config) {
    _config = config;
    _initialized = true;
    _readyFuture = Future<void>.value();
  }
}
