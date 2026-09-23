import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';

/// V2 article detail client — `GET /api/v2/article/{articleId}`.
///
/// Optional JWT (same pattern as V2 search / For You). Never uses V1 hosts
/// or V1 article endpoints.
class V2ArticleDetailApi {
  V2ArticleDetailApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  static const pathPrefix = '/api/v2/article';

  Future<NewsArticle> fetch(String articleId) async {
    final id = articleId.trim();
    if (id.isEmpty) {
      throw V2ArticleDetailException('missing_article_id');
    }

    String? bearerToken;
    if (_users.isLoggedIn) {
      final token = _users.getToken();
      if (token != null && token.isNotEmpty) bearerToken = token;
    }

    debugPrint('📰 V2 article detail id=$id auth=${bearerToken != null}');

    final response = await _api.getByPath(
      '$pathPrefix/$id',
      bearerToken: bearerToken,
      useV2Host: true,
    );

    if (!response.success) {
      if (response.statusCode == 404) {
        throw V2ArticleDetailException(
          'not_found',
          statusCode: 404,
          message: response.error,
        );
      }
      throw V2ArticleDetailException(
        'network_error',
        statusCode: response.statusCode,
        message: response.error,
      );
    }

    final article = _parse(response.data, fallbackId: id);
    if (article == null) {
      throw V2ArticleDetailException('invalid_payload');
    }
    return article;
  }

  /// Parses `{ success, data: {...} }` or a bare article map.
  static NewsArticle? _parse(dynamic raw, {required String fallbackId}) {
    if (raw == null) return null;

    Map<String, dynamic>? envelope;
    if (raw is Map<String, dynamic>) {
      envelope = raw;
    } else if (raw is Map) {
      envelope = Map<String, dynamic>.from(raw);
    }
    if (envelope == null) return null;

    dynamic data = envelope['data'];
    if (data == null &&
        (envelope.containsKey('articleId') ||
            envelope.containsKey('title') ||
            envelope.containsKey('content'))) {
      data = envelope;
    }
    if (data is! Map) return null;

    final map = Map<String, dynamic>.from(data);
    map.putIfAbsent('articleId', () => fallbackId);
    if (map['summarySource'] != null &&
        map['summary_status'] == null &&
        map['summaryStatus'] == null) {
      map['summaryStatus'] = map['summarySource'];
    }
    if (map['sourceName'] != null && map['source_name'] == null) {
      map['source_name'] = map['sourceName'];
    }

    return V2FeedItemMapper.fromItem(map);
  }
}

class V2ArticleDetailException implements Exception {
  V2ArticleDetailException(this.code, {this.statusCode, this.message});

  final String code;
  final int? statusCode;
  final String? message;

  @override
  String toString() => message ?? code;
}
