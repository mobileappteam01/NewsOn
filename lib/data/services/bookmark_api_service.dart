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
    final articles =
        dataList
            .map((item) => NewsArticle.fromJson(item as Map<String, dynamic>))
            .toList();

    return BookmarkListResponse(
      message: json['message'] as String? ?? 'success',
      pagination: pagination,
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

/// Service for handling bookmark API operations
class BookmarkApiService {
  static final BookmarkApiService _instance = BookmarkApiService._internal();
  factory BookmarkApiService() => _instance;
  BookmarkApiService._internal();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  /// Add bookmark
  /// POST /news/addBookmark
  /// Body: {"newsId": "article_id"}
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

  /// Get bookmark list
  /// GET /news/bookMarkList
  /// Query params: page, limit
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
