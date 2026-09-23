import '../../data/models/remote_config_model.dart';

/// Typed accessors for V2 Remote Config flags.
///
/// Optional staging-only overrides via `--dart-define=NEWSON_V2_*=true|false`.
/// When unset, Remote Config / defaults apply (production remains OFF).
abstract final class V2FeatureFlags {
  static bool newsCuts(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_NEWS_CUTS_ENABLED') ?? c.v2NewsCutsEnabled;
  /// Prefer `NEWSON_V2_ARTICLE_DETAIL_ENABLED` (phase name); keep
  /// `NEWSON_V2_NEW_ARTICLE_DETAIL_ENABLED` as a compatible alias.
  static bool newArticleDetail(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_ARTICLE_DETAIL_ENABLED') ??
      _defineOverride('NEWSON_V2_NEW_ARTICLE_DETAIL_ENABLED') ??
      c.v2NewArticleDetailEnabled;
  static bool fullArticle(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_FULL_ARTICLE_ENABLED') ??
      c.v2FullArticleEnabled;
  static bool relatedNews(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_RELATED_NEWS_ENABLED') ??
      c.v2RelatedNewsEnabled;
  static bool pageTurn(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_PAGE_TURN_ENABLED') ?? c.v2PageTurnEnabled;
  static bool publisherPages(RemoteConfigModel c) {
    final override = _defineOverride('NEWSON_V2_PUBLISHER_PAGES_ENABLED');
    if (override != null) return override;
    // Explicit Remote Config enable.
    if (c.v2PublisherPagesEnabled) return true;
    // V2 demo / product surface: when the V2 reader or V2 article detail is
    // already live, publisher navigation is part of that surface. Keeps V1
    // (all V2 flags off) unchanged when the RC key is missing/false.
    return homeReader(c) || newArticleDetail(c);
  }
  static bool search(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_SEARCH_ENABLED') ?? c.v2SearchEnabled;
  static bool forYou(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_FOR_YOU_ENABLED') ?? c.v2ForYouEnabled;
  static bool audio(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_AUDIO_ENABLED') ?? c.v2AudioEnabled;
  static bool audioGeneration(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_AUDIO_GENERATION_ENABLED') ??
      c.v2AudioGenerationEnabled;
  static bool notifications(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_NOTIFICATIONS_ENABLED') ??
      c.v2NotificationsEnabled;
  /// One-article V2 reader home. Default OFF — V1 / Cuts home unchanged.
  static bool homeReader(RemoteConfigModel c) =>
      _defineOverride('NEWSON_V2_HOME_READER_ENABLED') ??
      c.v2HomeReaderEnabled;

  /// Temporary local demo: pad the V2 reader to 3 pages when the feed has
  /// fewer than 3 articles. Default OFF. Compile-time only (no Remote Config).
  static bool readerDemoPages() =>
      _defineOverride('NEWSON_V2_READER_DEMO_PAGES') ?? false;

  /// Icon-only chrome when the V2 reader product surface is active.
  static bool v2Chrome(RemoteConfigModel c) =>
      homeReader(c) || newsCuts(c) || forYou(c) || search(c);

  static String cutsLabel(RemoteConfigModel c) => c.v2NewsCutsLabel;

  /// Returns null when the dart-define is unset (use Remote Config).
  static bool? _defineOverride(String key) {
    // fromEnvironment requires a constant key — callers pass string literals.
    switch (key) {
      case 'NEWSON_V2_NEWS_CUTS_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_NEWS_CUTS_ENABLED'),
        );
      case 'NEWSON_V2_ARTICLE_DETAIL_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_ARTICLE_DETAIL_ENABLED'),
        );
      case 'NEWSON_V2_NEW_ARTICLE_DETAIL_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_NEW_ARTICLE_DETAIL_ENABLED'),
        );
      case 'NEWSON_V2_FULL_ARTICLE_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_FULL_ARTICLE_ENABLED'),
        );
      case 'NEWSON_V2_RELATED_NEWS_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_RELATED_NEWS_ENABLED'),
        );
      case 'NEWSON_V2_PAGE_TURN_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_PAGE_TURN_ENABLED'),
        );
      case 'NEWSON_V2_PUBLISHER_PAGES_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_PUBLISHER_PAGES_ENABLED'),
        );
      case 'NEWSON_V2_SEARCH_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_SEARCH_ENABLED'),
        );
      case 'NEWSON_V2_FOR_YOU_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_FOR_YOU_ENABLED'),
        );
      case 'NEWSON_V2_AUDIO_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_AUDIO_ENABLED'),
        );
      case 'NEWSON_V2_AUDIO_GENERATION_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_AUDIO_GENERATION_ENABLED'),
        );
      case 'NEWSON_V2_NOTIFICATIONS_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_NOTIFICATIONS_ENABLED'),
        );
      case 'NEWSON_V2_HOME_READER_ENABLED':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_HOME_READER_ENABLED'),
        );
      case 'NEWSON_V2_READER_DEMO_PAGES':
        return _parseDefine(
          const String.fromEnvironment('NEWSON_V2_READER_DEMO_PAGES'),
        );
      default:
        return null;
    }
  }

  static bool? _parseDefine(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'true' || v == '1' || v == 'yes' || v == 'on') return true;
    if (v == 'false' || v == '0' || v == 'no' || v == 'off') return false;
    return null;
  }
}
