/// Remote-tunable ad policy (Firebase Realtime Database `ads_config`).
class AdPolicy {
  const AdPolicy({
    this.enabled = true,
    this.useTestAds = false,
    this.inlineInterval = 5,
    this.anchorBannerEnabled = true,
    this.interstitialEnabled = true,
    this.interstitialMinSeconds = 120,
    this.interstitialMinArticlesRead = 2,
    this.interstitialMaxPerSession = 4,
    this.forYouBlockAdsEnabled = true,
    this.searchInlineEnabled = true,
    this.bookmarksAnchorEnabled = true,
  });

  final bool enabled;
  /// Force Google test ad units (QA builds). Debug builds always use test units.
  final bool useTestAds;
  /// In-feed medium rectangle after every N articles.
  final int inlineInterval;
  final bool anchorBannerEnabled;
  final bool interstitialEnabled;
  final int interstitialMinSeconds;
  final int interstitialMinArticlesRead;
  final int interstitialMaxPerSession;
  final bool forYouBlockAdsEnabled;
  final bool searchInlineEnabled;
  final bool bookmarksAnchorEnabled;

  static const AdPolicy defaults = AdPolicy();

  factory AdPolicy.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;

    int parseInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic v, bool fallback) {
      if (v is bool) return v;
      if (v is String) {
        final lower = v.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    return AdPolicy(
      enabled: parseBool(map['enabled'], defaults.enabled),
      useTestAds: parseBool(map['use_test_ads'], defaults.useTestAds),
      inlineInterval: parseInt(map['inline_interval'], defaults.inlineInterval)
          .clamp(3, 12),
      anchorBannerEnabled: parseBool(
        map['anchor_banner_enabled'],
        defaults.anchorBannerEnabled,
      ),
      interstitialEnabled: parseBool(
        map['interstitial_enabled'],
        defaults.interstitialEnabled,
      ),
      interstitialMinSeconds: parseInt(
        map['interstitial_min_seconds'],
        defaults.interstitialMinSeconds,
      ).clamp(60, 600),
      interstitialMinArticlesRead: parseInt(
        map['interstitial_min_articles_read'],
        defaults.interstitialMinArticlesRead,
      ).clamp(1, 10),
      interstitialMaxPerSession: parseInt(
        map['interstitial_max_per_session'],
        defaults.interstitialMaxPerSession,
      ).clamp(1, 8),
      forYouBlockAdsEnabled: parseBool(
        map['for_you_block_ads_enabled'],
        defaults.forYouBlockAdsEnabled,
      ),
      searchInlineEnabled: parseBool(
        map['search_inline_enabled'],
        defaults.searchInlineEnabled,
      ),
      bookmarksAnchorEnabled: parseBool(
        map['bookmarks_anchor_enabled'],
        defaults.bookmarksAnchorEnabled,
      ),
    );
  }
}
