import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/deep_link_constants.dart';
import '../../core/utils/localization_helper.dart';
import '../models/news_article.dart';

/// Builds share text + deep link and opens the system share sheet.
class NewsShareService {
  NewsShareService._();

  static String? articleIdFor(NewsArticle article) {
    final id = article.articleId?.trim();
    if (id != null && id.isNotEmpty) return id;
    final newsId = article.newsId?.trim();
    if (newsId != null && newsId.isNotEmpty) return newsId;
    return null;
  }

  /// Title, catchy CTA, and app deep link only (no description body).
  ///
  /// When [v2] is true, emits an explicit V2 share URL
  /// (`https://v2-api.newson.app/v2/news/{id}`) so deep-link handling skips
  /// the V1 [NewsArticleResolver] and the browser hits the V2 HTML page.
  static String buildShareText(
    NewsArticle article, {
    String? curiousCta,
    bool v2 = false,
  }) {
    final id = articleIdFor(article);
    final buffer = StringBuffer();

    buffer.writeln(article.title);

    if (id != null) {
      final cta =
          curiousCta ?? LocalizationHelper.shareNewsCuriousCtaFallback();
      final httpsLink = v2
          ? DeepLinkConstants.buildV2HttpsDeepLink(id)
          : DeepLinkConstants.buildHttpsDeepLink(id);
      buffer.writeln();
      buffer.writeln(cta);
      buffer.writeln(httpsLink.toString());
    }

    return buffer.toString().trim();
  }

  static Future<void> shareArticle(
    NewsArticle article, {
    String? curiousCta,
    bool v2 = false,
  }) async {
    final id = articleIdFor(article);
    if (id == null) {
      debugPrint('⚠️ Cannot share: article has no articleId');
      await Share.share(
        buildShareText(article, curiousCta: curiousCta, v2: v2),
        subject: article.title,
      );
      return;
    }

    final text = buildShareText(article, curiousCta: curiousCta, v2: v2);
    final httpsUri = v2
        ? DeepLinkConstants.buildV2HttpsDeepLink(id)
        : DeepLinkConstants.buildHttpsDeepLink(id);

    await Share.share(
      text,
      subject: article.title,
    );

    debugPrint('📤 Shared article $id → ${httpsUri.toString()} (v2=$v2)');
  }
}
