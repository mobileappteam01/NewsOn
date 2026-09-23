import 'package:flutter/foundation.dart';

import '../../../data/models/for_you_response.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/news_response.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';

/// Fetches personalized For You feed from backend (Firestore endpoint: news/forYou).
///
/// V1 path — preserved for V1 `ForYouProvider` / `ForYouTab`.
/// V2 feed uses [V2ForYouApi] via `ForYouRepository`.
class ForYouService {
  static final ForYouService _instance = ForYouService._internal();
  factory ForYouService() => _instance;
  ForYouService._internal();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  static const String _module = 'news';
  static const String _endpointKey = 'forYou';

  /// GET For You feed with pagination.
  Future<ForYouResponse> fetchForYou({
    int page = 1,
    int limit = 10,
    String? userId,
  }) async {
    final resolvedUserId = userId ?? _userService.getUserId();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      throw Exception('User not authenticated. Please sign in.');
    }

    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated. Please sign in.');
    }

    debugPrint('📰 Fetching For You feed page=$page limit=$limit');

    // Wait for Firestore endpoints if cold-start raced ahead of download.
    await _apiService.ensureEndpoint(_module, _endpointKey);

    final response = await _apiService.get(
      _module,
      _endpointKey,
      queryParameters: {
        'userId': resolvedUserId,
        'page': page.toString(),
        'limit': limit.toString(),
      },
      bearerToken: token,
    );

    if (!response.success || response.data == null) {
      throw Exception(response.error ?? 'Failed to load For You feed');
    }

    final parsed = _parseResponse(response.data);
    debugPrint(
      '✅ For You: ${parsed.articles.length} articles (page ${parsed.pagination.page}/${parsed.pagination.totalPages})',
    );
    return parsed;
  }

  ForYouResponse _parseResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid For You response format');
    }

    final newsResponse = _parseNewsList(data);
    final paginationMap =
        data['pagination'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final currentPage = paginationMap['page'] as int? ?? 1;
    final totalPages = paginationMap['totalPages'] as int? ??
        (newsResponse.nextPage != null ? currentPage + 1 : currentPage);

    final pagination = paginationMap.isNotEmpty
        ? ForYouPagination.fromJson(paginationMap)
        : ForYouPagination(
            total: newsResponse.totalResults,
            page: currentPage,
            limit: newsResponse.results.length,
            totalPages: totalPages,
            hasNextPage: newsResponse.hasNextPage,
          );

    return ForYouResponse(
      message: data['message'] as String? ?? newsResponse.status,
      pagination: pagination,
      articles: newsResponse.results,
    );
  }

  /// Same shape as [BackendNewsService] list responses.
  NewsResponse _parseNewsList(Map<String, dynamic> data) {
    List<dynamic> results = [];
    if (data['data'] is List) {
      results = data['data'] as List;
    } else if (data['results'] is List) {
      results = data['results'] as List;
    }

    int totalResults = 0;
    int currentPage = 1;
    int totalPages = 1;
    String? nextPage;

    if (data['pagination'] is Map) {
      final pagination = data['pagination'] as Map<String, dynamic>;
      totalResults = pagination['total'] as int? ?? results.length;
      currentPage = pagination['page'] as int? ?? 1;
      totalPages = pagination['totalPages'] as int? ?? 1;
      if (currentPage < totalPages) {
        nextPage = (currentPage + 1).toString();
      }
    } else {
      totalResults =
          data['total'] as int? ?? data['totalResults'] as int? ?? results.length;
    }

    final articles = results
        .map((item) {
          try {
            return NewsArticle.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            debugPrint('⚠️ For You article parse error: $e');
            return null;
          }
        })
        .whereType<NewsArticle>()
        .toList();

    return NewsResponse(
      status: data['message'] as String? ?? 'success',
      totalResults: totalResults,
      results: articles,
      nextPage: nextPage,
    );
  }
}
