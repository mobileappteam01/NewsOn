import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/backend_news_service.dart';
import '../../../data/services/user_service.dart';
import '../domain/news_summary.dart';

/// Related news fetch with safe deterministic fallback.
///
/// Preferred: Firestore endpoint `news` / `relatedNews` when configured.
/// Fallback: same-category / same-publisher from recent today news (not AI).
class RelatedNewsService {
  RelatedNewsService({
    ApiService? apiService,
    BackendNewsService? backendNewsService,
  })  : _apiOverride = apiService,
        _backendOverride = backendNewsService;

  final ApiService? _apiOverride;
  final BackendNewsService? _backendOverride;
  ApiService? _apiLazy;
  BackendNewsService? _backendLazy;

  ApiService get _api {
    if (_apiOverride != null) return _apiOverride!;
    try {
      return _apiLazy ??= ApiService();
    } catch (_) {
      // Tests / no Firebase — callers treat as uninitialized.
      rethrow;
    }
  }

  BackendNewsService get _backend =>
      _backendOverride ?? (_backendLazy ??= BackendNewsService());

  static const _module = 'news';
  static const _endpointKey = 'relatedNews';

  Future<List<NewsArticle>> fetchRelated({
    required NewsArticle article,
    String? language,
    int limit = 6,
  }) async {
    final currentId = article.analyticsNewsId;

    try {
      if (_api.isInitialized) {
        final token = UserService().getToken();
        final response = await _api.get(
          _module,
          _endpointKey,
          queryParameters: {
            'newsId': article.newsId ?? article.articleId ?? '',
            'limit': '$limit',
            if (language != null && language.isNotEmpty) 'language': language,
          },
          bearerToken: (token != null && token.isNotEmpty) ? token : null,
        );
        if (response.success && response.data != null) {
          final list = _parseList(response.data);
          final filtered = list
              .where((a) => a.analyticsNewsId != currentId)
              .take(limit)
              .toList();
          if (filtered.isNotEmpty) return filtered;
        }
      }
    } catch (e) {
      debugPrint('ℹ️ relatedNews endpoint unavailable, using fallback: $e');
    }

    return _deterministicFallback(article, language: language, limit: limit);
  }

  Future<List<NewsArticle>> _deterministicFallback(
    NewsArticle article, {
    String? language,
    int limit = 6,
  }) async {
    try {
      final response = await _backend.fetchTodayNews(
        language: language,
        limit: 30,
        page: 1,
      );
      final currentId = article.analyticsNewsId;
      final publisher = article.sourceName?.toLowerCase();
      final category = article.category?.isNotEmpty == true
          ? article.category!.first.toLowerCase()
          : null;

      final scored = <(int, NewsArticle)>[];
      for (final a in response.results) {
        if (a.analyticsNewsId == currentId) continue;
        var score = 0;
        if (publisher != null && (a.sourceName?.toLowerCase() == publisher)) {
          score += 2;
        }
        if (category != null &&
            (a.category?.map((c) => c.toLowerCase()).contains(category) ??
                false)) {
          score += 1;
        }
        if (score > 0) scored.add((score, a));
      }
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      final related = scored.map((e) => e.$2).take(limit).toList();
      if (related.isNotEmpty) return related;

      // Last resort: recent others (still not personalized AI).
      return response.results
          .where((a) => a.analyticsNewsId != currentId)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Related fallback failed: $e');
      return const [];
    }
  }

  List<NewsArticle> _parseList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map>()
          .map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
