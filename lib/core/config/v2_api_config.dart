/// Typed V2 API host configuration loaded from Firestore `apiEndPoints/v2`.
///
/// Isolated from V1 (`ipAddress` + other `apiEndPoints` modules).
class V2ApiConfig {
  const V2ApiConfig({
    required this.baseUrl,
    required this.enabled,
  });

  /// Absolute API origin, e.g. `https://v2-api.newson.app` (no trailing slash required).
  final String baseUrl;

  /// When false, V2 features must not call the V2 host.
  final bool enabled;

  bool get isUsable =>
      enabled && baseUrl.trim().isNotEmpty && _looksLikeAbsoluteUrl(baseUrl);

  static bool _looksLikeAbsoluteUrl(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  /// Parses Firestore document fields. Accepts `baseUrl` / `base_url` and bool/string `enabled`.
  factory V2ApiConfig.fromFirestoreMap(Map<String, dynamic> data) {
    final rawBase = (data['baseUrl'] ?? data['base_url'] ?? '').toString().trim();
    final enabledRaw = data['enabled'];
    final enabled = enabledRaw == true ||
        enabledRaw == 1 ||
        (enabledRaw is String &&
            (enabledRaw.trim().toLowerCase() == 'true' ||
                enabledRaw.trim() == '1'));

    return V2ApiConfig(
      baseUrl: _stripTrailingSlash(rawBase),
      enabled: enabled,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'baseUrl': baseUrl,
        'enabled': enabled,
      };

  factory V2ApiConfig.fromCacheJson(Map<String, dynamic> json) {
    return V2ApiConfig.fromFirestoreMap(json);
  }

  static String _stripTrailingSlash(String url) {
    if (url.length > 1 && url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  String toString() => 'V2ApiConfig(baseUrl: $baseUrl, enabled: $enabled)';
}

/// Thrown when a V2 feature needs a host but Firebase/cache config is missing or disabled.
///
/// Callers must not fall back to the V1 base URL.
class V2ApiConfigException implements Exception {
  V2ApiConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}
