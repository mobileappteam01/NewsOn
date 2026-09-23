/// Deep links and store URLs for shared news.
class DeepLinkConstants {
  DeepLinkConstants._();

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.app.newson';

  /// Custom scheme — opens the app when installed (Android & iOS).
  static const String customScheme = 'newson';

  /// Host used in share HTTPS links (App Links when verified on api.newson.app).
  static const String httpsHost = 'api.newson.app';

  static const String articleIdQueryKey = 'articleId';

  /// Path segments for V2 article shares: `/v2/article/{articleId}`.
  static const String v2PathSegment = 'v2';
  static const String v2ArticleSegment = 'article';

  /// Builds: newson://news?articleId=...
  static Uri buildAppDeepLink(String articleId) {
    return Uri(
      scheme: customScheme,
      host: 'news',
      queryParameters: {articleIdQueryKey: articleId},
    );
  }

  /// Builds: https://api.newson.app/news/{articleId}
  static Uri buildHttpsDeepLink(String articleId) {
    return Uri(
      scheme: 'https',
      host: httpsHost,
      pathSegments: ['news', articleId],
    );
  }

  /// Builds: newson://v2/article/{articleId}
  static Uri buildV2AppDeepLink(String articleId) {
    return Uri(
      scheme: customScheme,
      host: v2PathSegment,
      pathSegments: [v2ArticleSegment, articleId],
    );
  }

  /// Builds: https://api.newson.app/v2/article/{articleId}
  static Uri buildV2HttpsDeepLink(String articleId) {
    return Uri(
      scheme: 'https',
      host: httpsHost,
      pathSegments: [v2PathSegment, v2ArticleSegment, articleId],
    );
  }

  /// True when URI is an explicit V2 article share link.
  static bool isV2ArticleDeepLink(Uri uri) {
    return parseV2ArticleId(uri) != null;
  }

  /// Parses Mongo ObjectId from V2 share links only (never V1 `/news/...`).
  static String? parseV2ArticleId(Uri uri) {
    final segments = uri.pathSegments;

    // newson://v2/article/{id}
    if (uri.scheme == customScheme &&
        uri.host == v2PathSegment &&
        segments.length >= 2 &&
        segments[0] == v2ArticleSegment) {
      final id = segments[1].trim();
      return id.isEmpty ? null : id;
    }

    // https://api.newson.app/v2/article/{id}
    if (uri.scheme == 'https' &&
        uri.host == httpsHost &&
        segments.length >= 3 &&
        segments[0] == v2PathSegment &&
        segments[1] == v2ArticleSegment) {
      final id = segments[2].trim();
      return id.isEmpty ? null : id;
    }

    // Optional query form: newson://v2?articleId=... or ?v=2
    if (uri.scheme == customScheme && uri.host == v2PathSegment) {
      final qp = uri.queryParameters[articleIdQueryKey] ??
          uri.queryParameters['id'];
      if (qp != null && qp.trim().isNotEmpty) return qp.trim();
    }

    return null;
  }

  /// Parses article id from V1 app / https share links.
  static String? parseArticleId(Uri uri) {
    // V2 links must not be treated as V1.
    if (isV2ArticleDeepLink(uri)) return null;

    final qp = uri.queryParameters[articleIdQueryKey] ??
        uri.queryParameters['id'] ??
        uri.queryParameters['article_id'];
    if (qp != null && qp.isNotEmpty) return qp;

    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments[0] == 'news' || segments[0] == 'article') &&
        segments[0] != v2PathSegment) {
      final id = segments[1];
      if (id.isNotEmpty) return id;
    }
    if (segments.length == 1 &&
        (uri.host == 'news' || uri.host == 'article' || uri.host == 'open')) {
      return segments[0];
    }

    if (uri.host == 'news' && uri.queryParameters.isNotEmpty) {
      for (final v in uri.queryParameters.values) {
        if (v.isNotEmpty) return v;
      }
    }

    return null;
  }

  static bool isNewsDeepLink(Uri uri) {
    if (isV2ArticleDeepLink(uri)) return true;
    if (uri.scheme == customScheme) return true;
    if (uri.scheme == 'https' && uri.host == httpsHost) {
      return parseArticleId(uri) != null;
    }
    return false;
  }

  /// Stable idempotency key for a deep link URI.
  static String? linkKey(Uri uri) {
    final v2 = parseV2ArticleId(uri);
    if (v2 != null) return 'v2:$v2';
    final v1 = parseArticleId(uri);
    if (v1 != null) return 'v1:$v1';
    return null;
  }
}
