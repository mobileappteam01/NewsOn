import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/deep_link_constants.dart';
import '../models/news_article.dart';

/// Builds share text + deep link and opens the system share sheet.
class NewsShareService {
  NewsShareService._();

  static String? articleIdFor(NewsArticle article) {
    final id = article.articleId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  static String buildShareText(NewsArticle article) {
    final id = articleIdFor(article);
    final buffer = StringBuffer();

    buffer.writeln(article.title);

    if (article.description != null && article.description!.trim().isNotEmpty) {
      final desc = article.description!.trim();
      buffer.writeln();
      buffer.writeln(
        desc.length > 280 ? '${desc.substring(0, 277)}...' : desc,
      );
    }

    buffer.writeln();
    if (id != null) {
      final httpsLink = DeepLinkConstants.buildHttpsDeepLink(id);
      // Primary tap target — opens the app when installed (App Link / deep link).
      buffer.writeln('Read in NewsOn:');
      buffer.writeln(httpsLink.toString());
      buffer.writeln();
      buffer.writeln('Don\'t have NewsOn? Install:');
      buffer.writeln(DeepLinkConstants.playStoreUrl);
    } else {
      buffer.writeln('Get NewsOn:');
      buffer.writeln(DeepLinkConstants.playStoreUrl);
    }

    if (article.link != null && article.link!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Source:');
      buffer.writeln(article.link!.trim());
    }

    return buffer.toString().trim();
  }

  static Future<void> shareArticle(NewsArticle article) async {
    final id = articleIdFor(article);
    if (id == null) {
      debugPrint('⚠️ Cannot share: article has no articleId');
      await Share.share(
        '${article.title}\n\n${article.link ?? ''}\n\n${DeepLinkConstants.playStoreUrl}',
      );
      return;
    }

    final text = buildShareText(article);
    final httpsUri = DeepLinkConstants.buildHttpsDeepLink(id);

    await Share.share(
      text,
      subject: article.title,
    );

    debugPrint('📤 Shared article $id → ${httpsUri.toString()}');
  }
}
