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
    return null;
  }

  /// Title, catchy CTA, and app deep link only (no description body).
  static String buildShareText(
    NewsArticle article, {
    String? curiousCta,
  }) {
    final id = articleIdFor(article);
    final buffer = StringBuffer();

    buffer.writeln(article.title);

    if (id != null) {
      final cta =
          curiousCta ?? LocalizationHelper.shareNewsCuriousCtaFallback();
      final httpsLink = DeepLinkConstants.buildHttpsDeepLink(id);
      buffer.writeln();
      buffer.writeln(cta);
      buffer.writeln(httpsLink.toString());
    }

    return buffer.toString().trim();
  }

  static Future<void> shareArticle(
    NewsArticle article, {
    String? curiousCta,
  }) async {
    final id = articleIdFor(article);
    if (id == null) {
      debugPrint('⚠️ Cannot share: article has no articleId');
      await Share.share(
        buildShareText(article, curiousCta: curiousCta),
        subject: article.title,
      );
      return;
    }

    final text = buildShareText(article, curiousCta: curiousCta);
    final httpsUri = DeepLinkConstants.buildHttpsDeepLink(id);

    await Share.share(
      text,
      subject: article.title,
    );

    debugPrint('📤 Shared article $id → ${httpsUri.toString()}');
  }
}
