import 'package:flutter/foundation.dart';

import '../models/news_article.dart';
import 'api_service.dart';
import 'user_service.dart';
import 'v2_api_config_service.dart';

/// Posts user interactions for personalization on the **V2 host only**.
///
/// Always uses `POST /api/interaction` with [useV2Host]. Never falls back to
/// `api.newson.app` / Firestore `news/postInteraction` (avoids V1 pollution
/// with V2 article IDs).
class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  ApiService? _apiService;
  final UserService _userService = UserService();

  ApiService? get _api {
    try {
      return _apiService ??= ApiService();
    } catch (_) {
      return null;
    }
  }

  /// Canonical V2 interaction path (same body shape as legacy; V2 host).
  static const String v2InteractionPath = '/api/interaction';

  /// Dedupe keys for the current app session (cleared on [clearSession]).
  final Set<String> _submittedKeys = {};

  void clearSession() => _submittedKeys.clear();

  @visibleForTesting
  void debugReset({ApiService? apiService}) {
    _apiService = apiService;
    _submittedKeys.clear();
  }

  String _dedupeKey(String action, String newsId) => '$action::$newsId';

  String? _resolveNewsId(NewsArticle article) {
    final newsId = article.newsId?.trim();
    if (newsId != null && newsId.isNotEmpty) return newsId;
    final articleId = article.articleId?.trim();
    if (articleId != null && articleId.isNotEmpty) return articleId;
    // Never fall back to title — V2 personalization requires ObjectId/newsId.
    return null;
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
      final api = _api;
      if (api == null) {
        debugPrint('⚠️ Interaction skipped — ApiService unavailable');
        return false;
      }

      try {
        await V2ApiConfigService.instance.ensureReady();
      } catch (_) {}
      final v2Base = V2ApiConfigService.instance.baseUrlIfEnabled;
      if (v2Base == null || v2Base.isEmpty) {
        debugPrint(
          '⚠️ Interaction skipped — V2 API not configured '
          '(refusing V1 api.newson.app fallback)',
        );
        return false;
      }

      final response = await api.postByPath(
        v2InteractionPath,
        body: body,
        bearerToken: token,
        useV2Host: true,
      );

      if (response.success) {
        _submittedKeys.add(dedupeKey);
        debugPrint('✅ Interaction posted ($action) via V2 for $newsId');
        return true;
      }

      debugPrint(
        '❌ Interaction failed ($action, V2): '
        '${response.statusCode} ${response.error}',
      );
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

  /// V2 bookmark persistence via `POST /api/interaction` (action=bookmark).
  ///
  /// Succeeds when the event is newly posted **or** already recorded this
  /// session. Throws on auth/config/network failure so callers can roll back
  /// optimistic UI. Never calls V1 `/api/bookmark/*`.
  Future<void> ensureBookmarkTracked(NewsArticle article) async {
    final userId = _userService.getUserId();
    final newsId = _resolveNewsId(article);
    if (userId == null || userId.isEmpty) {
      throw StateError('Bookmark requires login');
    }
    if (newsId == null || newsId.isEmpty) {
      throw StateError('Bookmark requires article id');
    }

    final dedupeKey = _dedupeKey('bookmark', newsId);
    if (_submittedKeys.contains(dedupeKey)) {
      return;
    }

    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Bookmark requires auth token');
    }

    final api = _api;
    if (api == null) {
      throw StateError('ApiService unavailable');
    }

    try {
      await V2ApiConfigService.instance.ensureReady();
    } catch (_) {}
    final v2Base = V2ApiConfigService.instance.baseUrlIfEnabled;
    if (v2Base == null || v2Base.isEmpty) {
      throw StateError('V2 API not configured for bookmark interaction');
    }

    final response = await api.postByPath(
      v2InteractionPath,
      body: {
        'userId': userId,
        'newsId': newsId,
        'categoryIds': _resolveCategoryIds(article),
        'action': 'bookmark',
        'duration': 0,
      },
      bearerToken: token,
      useV2Host: true,
    );

    if (!response.success) {
      throw StateError(
        response.error ??
            'V2 bookmark interaction failed (${response.statusCode})',
      );
    }
    _submittedKeys.add(dedupeKey);
    debugPrint('✅ Bookmark interaction posted via V2 for $newsId');
  }

  /// Allow a later re-bookmark after local unbookmark in the same session.
  void clearBookmarkDedupe(NewsArticle article) {
    final newsId = _resolveNewsId(article);
    if (newsId == null || newsId.isEmpty) return;
    _submittedKeys.remove(_dedupeKey('bookmark', newsId));
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
