import 'package:flutter/foundation.dart';

import '../models/news_article.dart';
import 'api_service.dart';
import 'user_service.dart';

/// Posts user interactions to backend (Firestore endpoint: news/postInteraction).
class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  static const String _module = 'news';
  static const String _endpointKey = 'postInteraction';

  /// Dedupe keys for the current app session (cleared on [clearSession]).
  final Set<String> _submittedKeys = {};

  void clearSession() => _submittedKeys.clear();

  String _dedupeKey(String action, String newsId) => '$action::$newsId';

  String? _resolveNewsId(NewsArticle article) {
    return article.newsId ??
        article.articleId ??
        (article.title.isNotEmpty ? article.title : null);
  }

  List<String> _resolveCategoryIds(NewsArticle article) {
    // API accepts category ObjectIds; article model exposes names only.
    // Backend resolves categories from the news document when this is empty.
    return const [];
  }

  Future<bool> _postInteraction({
    required String action,
    required NewsArticle article,
    int duration = 0,
    List<String>? categoryIds,
  }) async {
    final userId = _userService.getUserId();
    final newsId = _resolveNewsId(article);

    if (userId == null || userId.isEmpty) {
      debugPrint('⚠️ Interaction skipped — user not logged in');
      return false;
    }
    if (newsId == null || newsId.isEmpty) {
      debugPrint('⚠️ Interaction skipped — missing newsId');
      return false;
    }

    final dedupeKey = _dedupeKey(action, newsId);
    if (_submittedKeys.contains(dedupeKey)) {
      debugPrint('ℹ️ Duplicate interaction skipped: $dedupeKey');
      return false;
    }

    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ Interaction skipped — no auth token');
      return false;
    }

    final body = {
      'userId': userId,
      'newsId': newsId,
      'categoryIds': categoryIds ?? _resolveCategoryIds(article),
      'action': action,
      'duration': duration,
    };

    try {
      final response = await _apiService.post(
        _module,
        _endpointKey,
        body: body,
        bearerToken: token,
      );

      if (response.success) {
        _submittedKeys.add(dedupeKey);
        debugPrint('✅ Interaction posted: $action for $newsId');
        return true;
      }

      debugPrint('❌ Interaction failed: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('❌ Interaction error: $e');
      return false;
    }
  }

  Future<bool> trackOpen(NewsArticle article) {
    return _postInteraction(action: 'open', article: article);
  }

  Future<bool> trackRead(NewsArticle article, {required int duration}) {
    return _postInteraction(
      action: 'read',
      article: article,
      duration: duration,
    );
  }

  Future<bool> trackBookmark(NewsArticle article) {
    return _postInteraction(action: 'bookmark', article: article);
  }

  Future<bool> trackShare(NewsArticle article) {
    return _postInteraction(action: 'share', article: article);
  }

  Future<bool> trackCategoryClick(
    NewsArticle article, {
    List<String>? categoryIds,
  }) {
    return _postInteraction(
      action: 'category_click',
      article: article,
      categoryIds: categoryIds,
    );
  }
}
