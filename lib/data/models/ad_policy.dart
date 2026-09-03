/// Remote-tunable ad policy.
/// Most flags come from Realtime Database `ads_config`.
/// Detail-carousel flags are overridden by Firebase Remote Config.
class AdPolicy {
  const AdPolicy({
    this.enabled = true,
    this.useTestAds = false,
    this.inlineInterval = 5,
    this.anchorBannerEnabled = false,
    this.interstitialEnabled = false,
    this.interstitialMinSeconds = 120,
    this.interstitialMinArticlesRead = 2,
    this.interstitialMaxPerSession = 4,
    this.forYouBlockAdsEnabled = false,
    this.searchInlineEnabled = true,
    this.bookmarksAnchorEnabled = false,
    this.homeSectionBannerEnabled = true,
    this.detailCarouselAdsEnabled = true,
    this.detailCarouselAdInterval = 4,
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
  /// Banner between Breaking News and Today News on the Home Today tab.
  final bool homeSectionBannerEnabled;
  /// Inshorts-style full-page ads between detail carousel articles.
  final bool detailCarouselAdsEnabled;
  /// Insert an ad page after every N articles (3–8).
  final int detailCarouselAdInterval;

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
      // Interstitials removed per client request — keep false even if Firebase
      // still has interstitial_enabled: true.
      interstitialEnabled: false,
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
      homeSectionBannerEnabled: parseBool(
        map['home_section_banner_enabled'],
        defaults.homeSectionBannerEnabled,
      ),
      detailCarouselAdsEnabled: parseBool(
        map['detail_carousel_ads_enabled'],
        defaults.detailCarouselAdsEnabled,
      ),
      detailCarouselAdInterval: parseInt(
        map['detail_carousel_ad_interval'],
        defaults.detailCarouselAdInterval,
      ).clamp(3, 8),
    );
  }

  AdPolicy copyWith({
    bool? enabled,
    bool? useTestAds,
    int? inlineInterval,
    bool? anchorBannerEnabled,
    bool? interstitialEnabled,
    int? interstitialMinSeconds,
    int? interstitialMinArticlesRead,
    int? interstitialMaxPerSession,
    bool? forYouBlockAdsEnabled,
    bool? searchInlineEnabled,
    bool? bookmarksAnchorEnabled,
    bool? homeSectionBannerEnabled,
    bool? detailCarouselAdsEnabled,
    int? detailCarouselAdInterval,
  }) {
    return AdPolicy(
      enabled: enabled ?? this.enabled,
      useTestAds: useTestAds ?? this.useTestAds,
      inlineInterval: inlineInterval ?? this.inlineInterval,
      anchorBannerEnabled: anchorBannerEnabled ?? this.anchorBannerEnabled,
      interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
      interstitialMinSeconds:
          interstitialMinSeconds ?? this.interstitialMinSeconds,
      interstitialMinArticlesRead:
          interstitialMinArticlesRead ?? this.interstitialMinArticlesRead,
      interstitialMaxPerSession:
          interstitialMaxPerSession ?? this.interstitialMaxPerSession,
      forYouBlockAdsEnabled:
          forYouBlockAdsEnabled ?? this.forYouBlockAdsEnabled,
      searchInlineEnabled: searchInlineEnabled ?? this.searchInlineEnabled,
      bookmarksAnchorEnabled:
          bookmarksAnchorEnabled ?? this.bookmarksAnchorEnabled,
      homeSectionBannerEnabled:
          homeSectionBannerEnabled ?? this.homeSectionBannerEnabled,
      detailCarouselAdsEnabled:
          detailCarouselAdsEnabled ?? this.detailCarouselAdsEnabled,
      detailCarouselAdInterval:
          detailCarouselAdInterval ?? this.detailCarouselAdInterval,
    );
  }
}
