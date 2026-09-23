import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/models/news_response.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/backend_news_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/services/v2_api_config_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../../news/domain/news_summary.dart';
import '../domain/publisher_article_filter.dart';
import '../domain/publisher_model.dart';
import 'publisher_api.dart';

/// Coordinates publisher metadata + article lists.
///
/// V2: dedicated `GET /api/v2/publisher/{id}` + `.../news`.
/// Soft fallback: synthesize metadata from seed article + V2 search.
/// V1: Firestore publisher catalog when V2 host is off.
class PublisherRepository {
  PublisherRepository({
    PublisherApi? api,
    BackendNewsService? backendNewsService,
    ApiService? apiService,
    UserService? userService,
  })  : _apiOverride = api,
        _backendOverride = backendNewsService,
        _apiService = apiService,
        _userService = userService;

  PublisherApi? _apiOverride;
  BackendNewsService? _backendOverride;
  ApiService? _apiService;
  UserService? _userService;

  PublisherApi get _api => _apiOverride ??= PublisherApi();
  BackendNewsService get _backend =>
      _backendOverride ??= BackendNewsService();
  ApiService get _http => _apiService ??= ApiService();
  UserService get _users => _userService ??= UserService();

  final Map<String, PublisherModel> _cache = {};

  PublisherModel? getCached(String id) => _cache[id];

  bool get _v2Only {
    try {
      return V2ApiConfigService.instance.baseUrlIfEnabled != null;
    } catch (_) {
      return false;
    }
  }

  void cacheFromArticle(NewsArticle article) {
    final model = PublisherModel.fromArticleProvenance(
      displayName: article.publisherDisplayName,
      publisherId: article.publisherId,
      sourceId: article.sourceId,
      sourceName: article.sourceName,
      sourceUrl: article.sourceUrl,
      sourceIcon: article.sourceIcon,
    );
    _cache[model.routeId] = model;
    if (model.id != model.routeId) _cache[model.id] = model;
  }

  Future<PublisherModel> resolvePublisher({
    required String publisherKey,
    NewsArticle? seedArticle,
  }) async {
    final key = publisherKey.trim();
    if (key.isEmpty) {
      throw StateError('missing_publisher');
    }

    final cached = _cache[key];
    if (cached != null) {
      if (!cached.isActive) throw StateError('inactive_publisher');
      return cached;
    }

    final remote = await _api.fetchPublisher(key);
    if (remote != null) {
      if (!remote.isActive) throw StateError('inactive_publisher');
      _cache[key] = remote;
      _cache[remote.routeId] = remote;
      _cache[remote.id] = remote;
      return remote;
    }

    if (seedArticle != null) {
      final seedName = seedArticle.publisherDisplayName.trim();
      final seedId = seedArticle.publisherId?.trim() ?? '';
      // Only synthesize when we have a real brand name (never Mongo id as title).
      if (seedName.isNotEmpty &&
          seedName != 'Publisher' &&
          !NewsArticleSummaryX.isIngestionProviderLabel(seedName)) {
        final synthesized = PublisherModel.fromArticleProvenance(
          displayName: seedName,
          publisherId: seedId.isNotEmpty ? seedId : key,
          sourceId: seedArticle.sourceId,
          sourceName: seedArticle.sourceName,
          sourceUrl: seedArticle.sourceUrl,
          sourceIcon: seedArticle.sourceIcon,
        );
        _cache[key] = synthesized;
        _cache[synthesized.routeId] = synthesized;
        return synthesized;
      }
    }

    // V2: missing remote + no usable seed → not found (do not show raw id).
    if (_v2Only) {
      throw StateError('missing_publisher');
    }

    // V1 catalog soft fallback — identity from the route key alone.
    final fallback = PublisherModel(
      id: key,
      name: key,
      isActive: true,
      sourceName: key,
    );
    _cache[key] = fallback;
    return fallback;
  }

  Future<PublisherNewsPage> fetchArticles({
    required PublisherModel publisher,
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    final id = publisher.apiId.isNotEmpty ? publisher.apiId : publisher.routeId;
    final dedicated = await _api.fetchPublisherNews(
      publisherId: id,
      page: page,
      limit: limit,
      language: language,
    );
    if (dedicated != null) {
      return dedicated;
    }

    if (_v2Only) {
      return _v2SearchArticles(
        publisher: publisher,
        page: page,
        limit: limit,
        language: language,
      );
    }

    return _fallbackArticles(
      publisher: publisher,
      page: page,
      limit: limit,
      language: language,
    );
  }

  /// V2-only: `GET /api/v2/search` with optional `publisherId` filter.
  Future<PublisherNewsPage> _v2SearchArticles({
    required PublisherModel publisher,
    required int page,
    required int limit,
    String? language,
  }) async {
    final query = publisher.displayName.trim().isNotEmpty
        ? publisher.displayName.trim()
        : publisher.routeId;
    final queryParameters = <String, String>{
      'q': query.length >= 2 ? query : 'news',
      'page': '$page',
      'limit': '$limit',
    };
    if (publisher.id.isNotEmpty &&
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(publisher.id)) {
      queryParameters['publisherId'] = publisher.id;
    }
    final lang = language?.trim();
    if (lang != null && lang.isNotEmpty) {
      queryParameters['language'] = lang;
    }

    String? bearerToken;
    if (_users.isLoggedIn) {
      bearerToken = _users.getToken();
    }

    final response = await _http.getByPath(
      '/api/v2/search',
      queryParameters: queryParameters,
      bearerToken: bearerToken,
      useV2Host: true,
    );

    if (!response.success || response.data == null) {
      debugPrint(
        'ℹ️ Publisher V2 search unavailable: ${response.statusCode} ${response.error}',
      );
      return PublisherNewsPage(
        articles: const [],
        hasMore: false,
        page: page,
        fromDedicatedEndpoint: false,
      );
    }

    final pageData = V2FeedItemMapper.parseEnvelope(response.data);
    final filtered = PublisherArticleFilter.apply(
      pageData.articles,
      publisher,
    );

    return PublisherNewsPage(
      articles: filtered.take(limit).toList(),
      hasMore: pageData.hasMore || filtered.length >= limit,
      page: pageData.page,
      total: filtered.length,
      fromDedicatedEndpoint: false,
    );
  }

  Future<PublisherNewsPage> _fallbackArticles({
    required PublisherModel publisher,
    required int page,
    required int limit,
    String? language,
  }) async {
    try {
      // Prefer search by publisher display name when available.
      final query = publisher.displayName;
      NewsResponse response;
      try {
        response = await _backend.searchNews(
          query: query,
          language: language,
          limit: limit * 3,
          page: page,
        );
      } catch (_) {
        response = await _backend.fetchTodayNews(
          language: language,
          limit: 40,
          page: page,
        );
      }

      final filtered = PublisherArticleFilter.apply(
        response.results,
        publisher,
      ).take(limit).toList();

      final hasMore = filtered.length >= limit ||
          (response.nextPage != null && response.nextPage!.isNotEmpty);

      return PublisherNewsPage(
        articles: filtered,
        hasMore: hasMore,
        page: page,
        total: filtered.length,
        fromDedicatedEndpoint: false,
      );
    } catch (e) {
      debugPrint('❌ PublisherRepository fallback articles failed: $e');
      rethrow;
    }
  }
}
