import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/user_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../domain/home_filter_state.dart';
import '../domain/v2_home_metadata.dart';

/// V2 Home feed — `GET /api/v2/home` on the V2 host only.
class V2HomeApi {
  V2HomeApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  static const path = '/api/v2/home';

  Future<V2FeedPage> fetch({
    required HomeFilterState filter,
    required String language,
    int page = 1,
    int limit = 20,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 50);
    final query = filter.toQueryParameters(
      language: language,
      page: safePage,
      limit: safeLimit,
    );

    final token = _users.getToken();
    final bearer =
        (token != null && token.isNotEmpty && _users.isLoggedIn) ? token : null;

    debugPrint(
      '[V2HomeFilter] explicitCategories=[${query['category'] ?? ''}] '
      '(omit=backend-prefs)',
    );
    debugPrint(
      '[V2Home] GET $path page=$safePage '
      'language=${query['language'] ?? '-'} '
      'category=${query['category'] ?? '-'} '
      'country=${query['country'] ?? '-'} '
      'state=${query['state'] ?? '-'} '
      'city=${query['city'] ?? '-'}',
    );

    final response = await _api.getByPath(
      path,
      queryParameters: query,
      bearerToken: bearer,
      useV2Host: true,
    );

    if (!response.success || response.data == null) {
      throw V2HomeException(response.error ?? 'Failed to load Home');
    }
    final feedPage = V2FeedItemMapper.parseEnvelope(response.data);
    V2HomeCategoryDebug.logPage(feedPage);
    return feedPage;
  }
}

/// Categories + cascading regions. V2 host only. No NewsData.
class V2HomeMetadataApi {
  V2HomeMetadataApi({ApiService? apiService}) : _apiOrNull = apiService;

  ApiService? _apiOrNull;
  ApiService get _api => _apiOrNull ??= ApiService();

  Future<List<V2CategoryOption>> fetchCategories() async {
    final response = await _api.getByPath(
      '/api/v2/categories',
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2HomeException(response.error ?? 'Failed to load categories');
    }
    final imageBaseUrl = await _resolveImageBaseUrl();
    return V2CategoryOption.parseList(
      response.data,
      imageBaseUrl: imageBaseUrl,
    );
  }

  /// Shared image base used by media resolution (RTDB / Hive cache).
  Future<String?> _resolveImageBaseUrl() async {
    final live = _api.getImageBaseUrl()?.trim();
    if (live != null && live.isNotEmpty) return live;

    final cached = StorageService.getImageBaseUrlCache()?.trim();
    if (cached != null && cached.isNotEmpty) return cached;

    if (!_api.isInitialized) {
      try {
        await _api.initialize();
      } catch (e) {
        debugPrint('⚠️ V2 categories image base init skipped: $e');
      }
    }
    final after = _api.getImageBaseUrl()?.trim();
    if (after != null && after.isNotEmpty) return after;
    return StorageService.getImageBaseUrlCache()?.trim();
  }

  Future<List<V2RegionOption>> fetchCountries() async {
    final response = await _api.getByPath(
      '/api/v2/regions/countries',
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2HomeException(response.error ?? 'Failed to load countries');
    }
    // Exact V2 envelope: { success, data: { countries: [{ name, label }] } }
    return V2RegionOption.parseList(response.data);
  }

  Future<List<V2RegionOption>> fetchStates(String country) async {
    final response = await _api.getByPath(
      '/api/v2/regions/states',
      queryParameters: {'country': country.trim()},
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2HomeException(response.error ?? 'Failed to load states');
    }
    return V2RegionOption.parseList(response.data);
  }

  Future<List<V2RegionOption>> fetchCities({
    required String country,
    required String state,
  }) async {
    final response = await _api.getByPath(
      '/api/v2/regions/cities',
      queryParameters: {
        'country': country.trim(),
        'state': state.trim(),
      },
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2HomeException(response.error ?? 'Failed to load cities');
    }
    return V2RegionOption.parseList(response.data);
  }
}

class V2HomeException implements Exception {
  V2HomeException(this.message);
  final String message;
  @override
  String toString() => message;
}
