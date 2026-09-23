import 'package:flutter/foundation.dart';

import '../../../data/models/for_you_response.dart';
import '../../../data/models/region_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../../news/data/v2_feed_item_mapper.dart';

/// Phase 6 V2 For You client — `GET /api/v2/for-you`.
///
/// Optional JWT. Does not send userId as authority. V1 [ForYouService] unchanged.
class V2ForYouApi {
  V2ForYouApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  static const path = '/api/v2/for-you';

  Future<ForYouResponse> fetch({
    int page = 1,
    int limit = 15,
    String? language,
    SavedRegion? region,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 50);

    final query = <String, String>{
      'page': '$safePage',
      'limit': '$safeLimit',
    };

    final lang = language?.trim();
    if (lang != null && lang.isNotEmpty) query['language'] = lang;

    final country = region?.country?.trim();
    final state = region?.state?.trim();
    final district = region?.district?.trim();
    if (country != null && country.isNotEmpty) query['country'] = country;
    if (state != null && state.isNotEmpty) query['state'] = state;
    if (district != null && district.isNotEmpty) query['district'] = district;

    final token = _users.getToken();
    final bearer =
        (token != null && token.isNotEmpty && _users.isLoggedIn) ? token : null;

    debugPrint(
      '📰 V2 For You page=$safePage limit=$safeLimit auth=${bearer != null}',
    );

    final response = await _api.getByPath(
      path,
      queryParameters: query,
      bearerToken: bearer,
      useV2Host: true,
    );

    if (!response.success || response.data == null) {
      if (response.statusCode == 503) {
        throw Exception('V2 For You is disabled');
      }
      throw Exception(response.error ?? 'Failed to load For You feed');
    }

    final pageData = V2FeedItemMapper.parseEnvelope(response.data);
    final totalPages = pageData.hasMore ? safePage + 1 : safePage;

    debugPrint(
      '✅ V2 For You: ${pageData.articles.length} articles '
      '(page ${pageData.page}, mode=${pageData.mode ?? 'unknown'})',
    );

    return ForYouResponse(
      message: pageData.mode ?? 'ok',
      pagination: ForYouPagination(
        total: pageData.articles.length,
        page: pageData.page,
        limit: pageData.limit ?? safeLimit,
        totalPages: totalPages,
        hasNextPage: pageData.hasMore,
        hasPrevPage: pageData.page > 1,
      ),
      articles: pageData.articles,
    );
  }
}
