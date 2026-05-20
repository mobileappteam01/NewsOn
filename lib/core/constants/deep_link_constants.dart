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

  /// Parses article id from app / https share links.
  static String? parseArticleId(Uri uri) {
    final qp = uri.queryParameters[articleIdQueryKey] ??
        uri.queryParameters['id'] ??
        uri.queryParameters['article_id'];
    if (qp != null && qp.isNotEmpty) return qp;

    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments[0] == 'news' || segments[0] == 'article')) {
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
    if (uri.scheme == customScheme) return true;
    if (uri.scheme == 'https' && uri.host == httpsHost) {
      return parseArticleId(uri) != null;
    }
    return false;
  }
}
