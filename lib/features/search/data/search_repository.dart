import 'package:flutter/foundation.dart';

import '../../../data/models/news_response.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../domain/search_query_validator.dart';
import '../domain/search_session.dart';

class SearchException implements Exception {
  SearchException(this.code, [this.message]);
  final String code;
  final String? message;
  @override
  String toString() => message ?? code;
}

typedef SearchFetcher = Future<NewsResponse> Function({
  required String query,
  required String? language,
  required SearchFilters filters,
  required int page,
  required int limit,
});

/// V2 search repository — validates queries and calls `GET /api/v2/search`.
///
/// Does not call V1 `getActiveNewsMobile` when V2 search is used.
class SearchRepository {
  SearchRepository({
    ApiService? apiService,
    UserService? userService,
    SearchFetcher? searchFetcher,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService,
        _searchFetcher = searchFetcher;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;
  final SearchFetcher? _searchFetcher;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  static const path = '/api/v2/search';

  /// Query params for `GET /api/v2/search`. A null/empty [language] searches
  /// all languages; only explicit [filters] add location params.
  static Map<String, String> queryParametersFor({
    required String query,
    String? language,
    SearchFilters filters = const SearchFilters(),
    required int page,
    required int limit,
  }) {
    final lang = SearchLanguages.normalize(language);
    return {
      'q': query,
      'page': '$page',
      'limit': '$limit',
      if (lang != null) 'language': lang,
      ...filters.toQueryParameters(),
    };
  }

  Future<NewsResponse> search({
    required String query,
    String? language,
    SearchFilters filters = const SearchFilters(),
    int page = 1,
    int limit = SearchQueryValidator.defaultLimit,
  }) async {
    final error = SearchQueryValidator.validate(query);
    if (error != null) {
      throw SearchException(error);
    }
    final q = SearchQueryValidator.normalize(query);
    final clampedLimit = SearchQueryValidator.clampLimit(limit);
    final safePage = page < 1 ? 1 : page;

    final injected = _searchFetcher;
    if (injected != null) {
      return injected(
        query: q,
        language: SearchLanguages.normalize(language),
        filters: filters,
        page: safePage,
        limit: clampedLimit,
      );
    }

    final queryParameters = queryParametersFor(
      query: q,
      language: language,
      filters: filters,
      page: safePage,
      limit: clampedLimit,
    );

    String? bearerToken;
    if (_users.isLoggedIn) {
      bearerToken = _users.getToken();
    }

    final response = await _api.getByPath(
      path,
      queryParameters: queryParameters,
      bearerToken: bearerToken,
      useV2Host: true,
    );

    if (!response.success) {
      if (response.statusCode == 503) {
        throw SearchException('v2_disabled', response.error);
      }
      if (response.statusCode == 400) {
        throw SearchException('invalid_query', response.error);
      }
      throw SearchException('network_error', response.error);
    }

    final pageData = V2FeedItemMapper.parseEnvelope(response.data);
    debugPrint(
      '✅ V2 search: ${pageData.articles.length} items (page ${pageData.page})',
    );

    return NewsResponse(
      status: 'success',
      totalResults: pageData.articles.length,
      results: pageData.articles,
      nextPage: pageData.hasMore ? '${pageData.page + 1}' : null,
    );
  }
}
