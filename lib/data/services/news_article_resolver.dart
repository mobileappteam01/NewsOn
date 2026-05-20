import 'package:flutter/foundation.dart';

import '../../core/utils/connectivity_helper.dart';
import '../models/news_article.dart';
import '../repositories/news_repository.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Finds a [NewsArticle] in local caches by [articleId] or title fallback.
class NewsArticleResolver {
  NewsArticleResolver._();

  static String _key(NewsArticle article) =>
      article.articleId?.trim().isNotEmpty == true
          ? article.articleId!.trim()
          : article.title;

  /// Local cache first, then GET /api/latestnews/getNewsByIdMobile/:id when online.
  static Future<NewsArticle?> resolveById(String articleId) async {
    final cached = findById(articleId);
    if (cached != null) return cached;

    if (!await ConnectivityHelper.hasConnection()) {
      debugPrint('⚠️ resolveById: offline and article not cached');
      return null;
    }

    try {
      if (!ApiService().isInitialized) {
        await ApiService().initialize();
      }
      return await NewsRepository(apiKey: '').fetchArticleById(articleId);
    } catch (e) {
      debugPrint('⚠️ resolveById API fetch failed: $e');
      return null;
    }
  }

  static NewsArticle? findById(String articleId) {
    final id = articleId.trim();
    if (id.isEmpty) return null;

    final seen = <String>{};
    for (final article in _allCachedArticles()) {
      final key = _key(article);
      if (seen.contains(key)) continue;
      seen.add(key);

      if (article.articleId == id) return article;
      if (article.newsId == id) return article;
    }

    for (final article in _allCachedArticles()) {
      if (article.title == id) return article;
    }

    debugPrint('⚠️ NewsArticleResolver: no article for id=$id');
    return null;
  }

  static List<NewsArticle> _allCachedArticles() {
    final out = <NewsArticle>[];
    out.addAll(StorageService.getBreakingNewsCache());
    out.addAll(StorageService.getTodayNewsCache());
    out.addAll(StorageService.getArticlesCache());
    out.addAll(StorageService.getBookmarkListCache());
    out.addAll(StorageService.getAllBookmarks());
    return out;
  }
}
