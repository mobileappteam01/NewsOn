import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/services/v2_api_config_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../domain/publisher_model.dart';

/// Result of a publisher news page fetch.
class PublisherNewsPage {
  const PublisherNewsPage({
    required this.articles,
    this.hasMore = false,
    this.page = 1,
    this.total,
    this.fromDedicatedEndpoint = false,
  });

  final List<NewsArticle> articles;
  final bool hasMore;
  final int page;
  final int? total;
  final bool fromDedicatedEndpoint;
}

/// Public publisher client.
///
/// V2 (preferred when host enabled):
/// - `GET /api/v2/publisher/{publisherId}`
/// - `GET /api/v2/publisher/{publisherId}/news?page&limit&language`
///
/// V1 catalog fallback (Firestore module `publishers`) when V2 host is off.
class PublisherApi {
  PublisherApi({
    ApiService? apiService,
    UserService? userService,
  })  : _api = apiService ?? ApiService(),
        _users = userService ?? UserService();

  final ApiService _api;
  final UserService _users;

  static const module = 'publishers';
  static const getByIdKey = 'getById';
  static const newsKey = 'news';
  static const v2PathPrefix = '/api/v2/publisher';

  String? get _token {
    final t = _users.getToken();
    if (t != null && t.isNotEmpty) return t;
    return null;
  }

  bool get _v2Only {
    try {
      return V2ApiConfigService.instance.baseUrlIfEnabled != null;
    } catch (_) {
      return false;
    }
  }

  Future<PublisherModel?> fetchPublisher(String publisherId) async {
    final id = publisherId.trim();
    if (id.isEmpty) return null;

    if (_v2Only) {
      return _fetchV2Publisher(id);
    }
    return _fetchV1CatalogPublisher(id);
  }

  Future<PublisherNewsPage?> fetchPublisherNews({
    required String publisherId,
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    final id = publisherId.trim();
    if (id.isEmpty) return null;

    if (_v2Only) {
      return _fetchV2PublisherNews(
        publisherId: id,
        page: page,
        limit: limit,
        language: language,
      );
    }
    return _fetchV1CatalogNews(
      publisherId: id,
      page: page,
      limit: limit,
      language: language,
    );
  }

  Future<PublisherModel?> _fetchV2Publisher(String id) async {
    try {
      debugPrint(
        '[PublisherAPI] GET /api/v2/publisher/$id',
      );
      final response = await _api.getByPath(
        '$v2PathPrefix/$id',
        bearerToken: _token,
        useV2Host: true,
      );
      if (!response.success || response.data == null) {
        debugPrint(
          'ℹ️ V2 publisher details failed: ${response.statusCode} ${response.error}',
        );
        return null;
      }
      final map = _unwrapDataMap(response.data);
      if (map == null) return null;
      map.putIfAbsent('id', () => id);
      map.putIfAbsent('_id', () => id);
      return PublisherModel.fromJson(map);
    } catch (e) {
      debugPrint('ℹ️ V2 publisher details unavailable: $e');
      return null;
    }
  }

  Future<PublisherNewsPage?> _fetchV2PublisherNews({
    required String publisherId,
    required int page,
    required int limit,
    String? language,
  }) async {
    try {
      final query = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      final lang = language?.trim();
      if (lang != null && lang.isNotEmpty) {
        query['language'] = lang;
      }

      debugPrint(
        '[PublisherAPI] GET /api/v2/publisher/$publisherId/news '
        'page=$page limit=$limit language=${lang ?? '-'}',
      );
      final response = await _api.getByPath(
        '$v2PathPrefix/$publisherId/news',
        queryParameters: query,
        bearerToken: _token,
        useV2Host: true,
      );
      if (!response.success || response.data == null) {
        debugPrint(
          'ℹ️ V2 publisher news failed: ${response.statusCode} ${response.error}',
        );
        return null;
      }
      return _parseV2NewsPage(response.data, page: page, limit: limit);
    } catch (e) {
      debugPrint('ℹ️ V2 publisher news unavailable: $e');
      return null;
    }
  }

  PublisherNewsPage _parseV2NewsPage(
    dynamic data, {
    required int page,
    required int limit,
  }) {
    // Prefer the shared V2 feed envelope parser (items + hasNextPage).
    final feed = V2FeedItemMapper.parseEnvelope(data);
    final explicitHasNext = _readHasNext(data);
    // Prefer dedicated hasNextPage when present in the envelope.
    final hasMore = feed.hasMore || explicitHasNext;
    return PublisherNewsPage(
      articles: feed.articles,
      hasMore: hasMore,
      page: feed.page > 0 ? feed.page : page,
      total: feed.articles.length,
      fromDedicatedEndpoint: true,
    );
  }

  bool _readHasNext(dynamic data) {
    if (data is! Map) return false;
    final map = Map<String, dynamic>.from(data);
    final nested = map['data'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : map;
    return payload['hasNextPage'] == true ||
        payload['has_more'] == true ||
        payload['hasMore'] == true;
  }

  Map<String, dynamic>? _unwrapDataMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (map.containsKey('name') ||
        map.containsKey('id') ||
        map.containsKey('_id') ||
        map.containsKey('publisherId')) {
      return map;
    }
    return null;
  }

  Future<PublisherModel?> _fetchV1CatalogPublisher(String id) async {
    if (!_api.isInitialized) return null;
    try {
      await _api.ensureEndpoint(module, getByIdKey);
      final response = await _api.get(
        module,
        getByIdKey,
        queryParameters: {
          'publisherId': id,
          'id': id,
          'slug': id,
        },
        bearerToken: _token,
      );
      if (!response.success || response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return PublisherModel.fromJson(data);
      }
      if (data is Map) {
        return PublisherModel.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('ℹ️ PublisherApi V1 catalog unavailable: $e');
    }
    return null;
  }

  Future<PublisherNewsPage?> _fetchV1CatalogNews({
    required String publisherId,
    required int page,
    required int limit,
    String? language,
  }) async {
    if (!_api.isInitialized) return null;
    try {
      await _api.ensureEndpoint(module, newsKey);
      final response = await _api.get(
        module,
        newsKey,
        queryParameters: {
          'publisherId': publisherId,
          'id': publisherId,
          'slug': publisherId,
          'page': '$page',
          'limit': '$limit',
          if (language != null && language.isNotEmpty) 'language': language,
        },
        bearerToken: _token,
      );
      if (!response.success || response.data == null) return null;
      return _parseLegacyNewsPage(response.data, page: page, limit: limit);
    } catch (e) {
      debugPrint('ℹ️ PublisherApi V1 news unavailable: $e');
      return null;
    }
  }

  PublisherNewsPage _parseLegacyNewsPage(
    dynamic data, {
    required int page,
    required int limit,
  }) {
    List<dynamic> rawList = const [];
    Map<String, dynamic>? pagination;

    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested =
          map['data'] ?? map['results'] ?? map['news'] ?? map['articles'];
      if (nested is List) {
        rawList = nested;
      } else if (nested is Map) {
        final inner = nested['results'] ?? nested['news'] ?? nested['data'];
        if (inner is List) rawList = inner;
      }
      final p = map['pagination'];
      if (p is Map) pagination = Map<String, dynamic>.from(p);
    }

    final articles = <NewsArticle>[];
    final seen = <String>{};
    for (final item in rawList) {
      if (item is! Map) continue;
      try {
        final mapped = V2FeedItemMapper.fromItem(item) ??
            NewsArticle.fromJson(Map<String, dynamic>.from(item));
        final id = mapped.newsId ?? mapped.articleId ?? mapped.title;
        if (seen.contains(id)) continue;
        seen.add(id);
        articles.add(mapped);
      } catch (_) {}
    }

    final hasMore = pagination?['hasMore'] == true ||
        pagination?['has_more'] == true ||
        (pagination?['nextPage'] != null) ||
        articles.length >= limit;

    final total = pagination?['total'] is int
        ? pagination!['total'] as int
        : int.tryParse('${pagination?['total'] ?? ''}');

    return PublisherNewsPage(
      articles: articles,
      hasMore: hasMore,
      page: page,
      total: total,
      fromDedicatedEndpoint: true,
    );
  }
}
