import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../models/news_article.dart';

/// Response model for bookmark list API
class BookmarkListResponse {
  final String message;
  final PaginationInfo pagination;
  final List<NewsArticle> data;

  BookmarkListResponse({
    required this.message,
    required this.pagination,
    required this.data,
  });

  factory BookmarkListResponse.fromJson(Map<String, dynamic> json) {
    final paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
    final pagination = PaginationInfo.fromJson(paginationData);

    final dataList = json['data'] as List<dynamic>? ?? [];
    // Backend returns a flat news array. Each item's `_id` is the news Mongo id
    // used by removeBookmark/:newsId.
    final articles = dataList.map((item) {
      if (item is! Map) {
        return NewsArticle.fromJson(const <String, dynamic>{});
      }
      final map = Map<String, dynamic>.from(item);
      final nested = map['news'];
      if (nested is Map) {
        final articleMap = Map<String, dynamic>.from(nested);
        articleMap['_id'] ??= map['newsId'] ?? map['_id'] ?? nested['_id'];
        articleMap['isBookmarked'] = true;
        return NewsArticle.fromJson(articleMap);
      }
      map['isBookmarked'] = true;
      return NewsArticle.fromJson(map);
    }).where((a) {
      final hasId = a.newsId != null && a.newsId!.trim().isNotEmpty;
      final hasTitle = a.title.trim().isNotEmpty && a.title != 'No Title';
      return hasId || hasTitle;
    }).toList();

    return BookmarkListResponse(
      message: json['message'] as String? ?? 'success',
      pagination: pagination,
      data: articles,
    );
  }

  /// `GET /api/v2/bookmarks` body: `{ items, page, limit, hasNextPage }`.
  ///
  /// Returns null when `items` is missing so callers treat it as a failed
  /// refresh and keep the visible list (never a false empty wipe).
  static BookmarkListResponse? tryFromV2Data(Map<String, dynamic> json) {
    if (!json.containsKey('items')) return null;
    final rawItems = json['items'];
    if (rawItems is! List) return null;
    return BookmarkListResponse.fromV2Data(json);
  }

  /// `GET /api/v2/bookmarks` body: `{ items, page, limit, hasNextPage }`.
  factory BookmarkListResponse.fromV2Data(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final dataList = rawItems is List ? rawItems : const <dynamic>[];
    final articles = dataList.map((item) {
      if (item is! Map) {
        return NewsArticle.fromJson(const <String, dynamic>{});
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['articleId'] ?? map['newsId'] ?? map['_id'];
      map['_id'] ??= id;
      map['article_id'] ??= id;
      map['articleId'] ??= id;
      map['image_url'] ??= map['image'];
      map['pubDate'] ??= map['publishedAt'];
      map['isBookmarked'] = true;
      return NewsArticle.fromJson(map);
    }).where((a) {
      final hasId = a.newsId != null && a.newsId!.trim().isNotEmpty;
      final hasTitle = a.title.trim().isNotEmpty && a.title != 'No Title';
      return hasId || hasTitle;
    }).toList();

    final page = json['page'] is int ? json['page'] as int : 1;
    final limit = json['limit'] is int ? json['limit'] as int : 20;
    final hasNext = json['hasNextPage'] == true;
    return BookmarkListResponse(
      message: 'success',
      pagination: PaginationInfo(
        total: articles.length,
        page: page < 1 ? 1 : page,
        limit: limit < 1 ? 20 : limit,
        totalPages: hasNext ? page + 1 : page,
      ),
      data: articles,
    );
  }
}

/// Pagination info model
class PaginationInfo {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginationInfo({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  bool get hasMore => page < totalPages;
}

/// Service for handling bookmark API operations.
/// [newsId] must be the news article MongoDB `_id` — never `article_id`.
class BookmarkApiService {
  static final BookmarkApiService _instance = BookmarkApiService._internal();
  factory BookmarkApiService() => _instance;
  BookmarkApiService._internal();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  /// Add bookmark
  /// POST /news/addBookmark
  /// Body: {"newsId": "<Mongo _id of news article>"}
  Future<bool> addBookmark(String newsId) async {
    try {
      final token = _userService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please sign in.');
      }

      debugPrint('🔖 Adding bookmark for newsId: $newsId');

      final response = await _apiService.post(
        'news',
        'addBookMark',
        body: {'newsId': newsId},
        bearerToken: token,
      );

      if (response.success) {
        debugPrint('✅ Bookmark added successfully');
        return true;
      } else {
        debugPrint('❌ Failed to add bookmark: ${response.error}');
        throw Exception(response.error ?? 'Failed to add bookmark');
      }
    } catch (e) {
      debugPrint('❌ Error adding bookmark: $e');
      rethrow;
    }
  }

  /// Remove bookmark
  /// DELETE /news/removeBookmark
  /// Header: newsId
  Future<bool> removeBookmark(String newsId) async {
    try {
      final token = _userService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please sign in.');
      }

      // Validate newsId
      if (newsId.isEmpty) {
        throw Exception('newsId cannot be empty');
      }

      debugPrint('🗑️ Removing bookmark for newsId: $newsId');
      debugPrint('🗑️ Module: news, Endpoint: removeBookMark');
      debugPrint('🗑️ newsId will be appended to URL as path parameter');

      // For DELETE, newsId should be passed as a path parameter in the URL
      // The endpoint from Firebase is /api/bookmark/removeBookmark
      // We append /{newsId} to make it /api/bookmark/removeBookmark/{newsId}
      final response = await _apiService.delete(
        'news',
        'removeBookMark',
        bearerToken: token,
        pathParameters: {'newsId': newsId}, // Pass newsId as path parameter
      );

      if (response.success) {
        debugPrint('✅ Bookmark removed successfully');
        return true;
      } else {
        debugPrint('❌ Failed to remove bookmark: ${response.error}');
        throw Exception(response.error ?? 'Failed to remove bookmark');
      }
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      rethrow;
    }
  }

  /// Remove all bookmarks for the current user.
  ///
  /// Backend (live):
  ///   DELETE /api/bookmark/removeAllBookmarks
  ///   DELETE /api/bookmark/removeAllBookMarks  (alias)
  ///
  /// Tries Firestore endpoint keys first, then hardcoded production paths.
  Future<bool> removeAllBookmarks() async {
    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated. Please sign in.');
    }

    debugPrint('🗑️ Removing all bookmarks via bulk API');

    // Prefer hardcoded production paths first (backend-confirmed, no Firestore wait).
    for (final path in [
      '/api/bookmark/removeAllBookmarks',
      '/api/bookmark/removeAllBookMarks',
    ]) {
      try {
        final response = await _apiService.deleteByPath(
          path,
          bearerToken: token,
        );
        if (response.success) {
          final deleted = _readDeletedCount(response.data);
          debugPrint(
            '✅ All bookmarks removed via $path'
            '${deleted != null ? ' (deletedCount=$deleted)' : ''}',
          );
          return true;
        }
        debugPrint('⚠️ Bulk path $path failed: ${response.error}');
      } catch (e) {
        debugPrint('⚠️ Bulk path $path error: $e');
      }
    }

    // Fallback: Firestore-configured keys under module "news" (if present).
    for (final key in ['removeAllBookMarks', 'removeAllBookmarks']) {
      try {
        await _apiService.ensureEndpoint('news', key);
        final response = await _apiService.delete(
          'news',
          key,
          bearerToken: token,
        );
        if (response.success) {
          final deleted = _readDeletedCount(response.data);
          debugPrint(
            '✅ All bookmarks removed via endpoint key "$key"'
            '${deleted != null ? ' (deletedCount=$deleted)' : ''}',
          );
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Bulk key "$key" unavailable: $e');
      }
    }

    throw Exception('Failed to remove all bookmarks');
  }

  int? _readDeletedCount(dynamic data) {
    if (data is Map) {
      final raw = data['deletedCount'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
    }
    return null;
  }

  /// Persists a V2 bookmark. `POST /api/v2/bookmarks` body `{ newsId }`.
  ///
  /// Bearer auth. 201 creates a row; 200 means this user already bookmarked
  /// that article. Both write the MongoDB `bookmarks` collection read by
  /// `GET /api/v2/bookmarks`.
  Future<void> addV2Bookmark(String newsId) async {
    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[V2Bookmark] add failed');
      throw Exception('User not authenticated. Please sign in.');
    }
    final id = newsId.trim();
    if (id.isEmpty) {
      debugPrint('[V2Bookmark] add failed');
      throw Exception('Cannot bookmark: missing article id');
    }
    debugPrint('[V2Bookmark] add request started');
    final response = await _apiService.postByPath(
      '/api/v2/bookmarks',
      body: {'newsId': id},
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success) {
      debugPrint('[V2Bookmark] add failed');
      throw Exception(response.error ?? 'Failed to bookmark article');
    }
    debugPrint('[V2Bookmark] add success');
  }

  /// Removes a V2 bookmark. `DELETE /api/v2/bookmarks/{newsId}` on the V2 host.
  Future<void> deleteV2Bookmark(String newsId) async {
    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated. Please sign in.');
    }
    final id = newsId.trim();
    if (id.isEmpty) {
      throw Exception('Cannot remove bookmark: missing article id');
    }
    final response = await _apiService.deleteByPath(
      '/api/v2/bookmarks/$id',
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success) {
      throw Exception(response.error ?? 'Failed to remove bookmark');
    }
  }

  /// V2 bookmark list. `GET /api/v2/bookmarks` on the V2 host.
  ///
  /// Returns null when the route is missing or the call fails so callers can
  /// keep the list confirmed by a successful bookmark write. Never falls
  /// back to the V1 bookmark catalog.
  Future<BookmarkListResponse?> tryGetV2BookmarkList({
    int page = 1,
    int limit = 20,
  }) async {
    final token = _userService.getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _apiService.getByPath(
        '/api/v2/bookmarks',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
        bearerToken: token,
        useV2Host: true,
      );
      if (!response.success || response.data == null) return null;
      final raw = response.data;
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      }
      if (map == null) return null;
      final data = map['data'];
      BookmarkListResponse? parsed;
      if (data is Map<String, dynamic>) {
        parsed = BookmarkListResponse.tryFromV2Data(data);
      } else if (data is Map) {
        parsed = BookmarkListResponse.tryFromV2Data(
          Map<String, dynamic>.from(data),
        );
      } else if (data is List) {
        parsed = BookmarkListResponse.fromJson(map);
      }
      if (parsed == null) return null;
      debugPrint('[V2Bookmark] list success count=${parsed.data.length}');
      return parsed;
    } catch (e) {
      debugPrint('ℹ️ V2 bookmark list unavailable: $e');
      return null;
    }
  }

  /// Get bookmark list
  /// GET /news/bookMarkList  → backend: GET /api/bookmark/getAllBookmarks
  /// Query params: page, limit
  /// Each item is a flat news object; `_id` is the news Mongo ObjectId.
  Future<BookmarkListResponse> getBookmarkList({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = _userService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please sign in.');
      }

      debugPrint('📋 Fetching bookmark list - Page: $page, Limit: $limit');

      final response = await _apiService.get(
        'news',
        'bookMarkList',
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
        bearerToken: token,
      );

      if (response.success && response.data != null) {
        final bookmarkResponse = BookmarkListResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        debugPrint(
          '✅ Bookmark list fetched: ${bookmarkResponse.data.length} items',
        );
        return bookmarkResponse;
      } else {
        debugPrint('❌ Failed to fetch bookmark list: ${response.error}');
        throw Exception(response.error ?? 'Failed to fetch bookmark list');
      }
    } catch (e) {
      debugPrint('❌ Error fetching bookmark list: $e');
      rethrow;
    }
  }
}
