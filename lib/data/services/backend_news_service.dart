import 'package:flutter/foundation.dart';
import '../models/news_response.dart';
import '../models/news_article.dart';
import 'api_service.dart';
import 'user_service.dart';

/// Backend News Service - Fetches news from backend API
/// Uses ApiService to call endpoints from Firestore apiEndPoints collection
class BackendNewsService {
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  /// Convert language code to full language name for backend API
  /// Backend API expects: 'english', 'tamil', 'hindi' instead of 'en', 'ta', 'hi'
  String? _convertLanguageCodeToName(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return null;

    const languageMap = {'en': 'english', 'ta': 'tamil', 'hi': 'hindi'};

    return languageMap[languageCode.toLowerCase()] ??
        languageCode.toLowerCase();
  }

  /// Fetch breaking news from backend
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 10 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchBreakingNews({
    String? language,
    int limit = 10,
    int page = 1,
  }) async {
    try {
      debugPrint('📰 Fetching breaking news from backend...');
      // Convert language code to full language name for backend API
      final languageName = _convertLanguageCodeToName(language);
      debugPrint(
        '   Language Code: $language → Language Name: $languageName, Limit: $limit, Page: $page',
      );
      final queryParameters = <String, String>{
        if (languageName != null && languageName.isNotEmpty)
          'language': languageName,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Get bearer token if user is logged in
      String? bearerToken;
      if (_userService.isLoggedIn) {
        bearerToken = _userService.getToken();
      }

      // Call backend API using ApiService
      final response = await _apiService.get(
        'news', // Module name in apiEndPoints collection
        'breakingNews', // Endpoint key: "api/latestnews/getActiveNewsMobile"
        queryParameters: queryParameters,
        bearerToken: bearerToken,
      );

      if (response.success && response.data != null) {
        debugPrint('✅ Breaking news fetched successfully');
        return _parseNewsResponse(response.data);
      } else {
        throw Exception(response.error ?? 'Failed to fetch breaking news');
      }
    } catch (e) {
      debugPrint('❌ Error fetching breaking news: $e');
      rethrow;
    }
  }

  /// Fetch today's news from backend
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [date] - Date in format 'YYYY-MM-DD' (optional, defaults to today)
  /// [limit] - Number of items to fetch (default: 5 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchTodayNews({
    String? language,
    String? date,
    int limit = 5,
    int page = 1,
  }) async {
    try {
      debugPrint('📰 Fetching today\'s news from backend...');
      // Convert language code to full language name for backend API
      final languageName = _convertLanguageCodeToName(language);
      debugPrint(
        '   Language Code: $language → Language Name: $languageName, Date: $date, Limit: $limit, Page: $page',
      );
      final queryParameters = <String, String>{
        if (languageName != null && languageName.isNotEmpty)
          'language': languageName,
        if (date != null && date.isNotEmpty) 'date': date,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Get bearer token if user is logged in
      String? bearerToken;
      if (_userService.isLoggedIn) {
        bearerToken = _userService.getToken();
      }

      // Call backend API using ApiService
      final response = await _apiService.get(
        'news', // Module name in apiEndPoints collection
        'todayNews', // Endpoint key: "api/latestnews/getActiveNewsMobile"
        queryParameters: queryParameters,
        bearerToken: bearerToken,
      );

      if (response.success && response.data != null) {
        debugPrint('✅ Today\'s news fetched successfully');
        return _parseNewsResponse(response.data);
      } else {
        throw Exception(response.error ?? 'Failed to fetch today\'s news');
      }
    } catch (e) {
      debugPrint('❌ Error fetching today\'s news: $e');
      rethrow;
    }
  }

  /// Fetch news by category from backend
  /// [categories] - List of category names (e.g., ['business', 'sports'])
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch
  /// [page] - Page number for pagination
  /// 
  /// API Format: /getActiveNewsMobile?category=top&category=lifestyle
  /// Multiple categories are passed as repeated query parameters
  Future<NewsResponse> fetchNewsByCategory({
    required String category,
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      debugPrint('📰 Fetching news by category from backend...');
      // Convert language code to full language name for backend API
      final languageName = _convertLanguageCodeToName(language);
      debugPrint(
        '   Category: $category, Language Code: $language → Language Name: $languageName, Limit: $limit, Page: $page',
      );
      
      // Build query parameters
      // Category can be a single value or comma-separated list
      final queryParameters = <String, String>{
        'category': category,
        if (languageName != null && languageName.isNotEmpty)
          'language': languageName,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Get bearer token if user is logged in
      String? bearerToken;
      if (_userService.isLoggedIn) {
        bearerToken = _userService.getToken();
      }

      // Call backend API using newsByCategory endpoint
      // Falls back to breakingNews if newsByCategory doesn't exist
      final response = await _apiService.get(
        'news',
        'newsByCategory', // Use dedicated category endpoint
        queryParameters: queryParameters,
        bearerToken: bearerToken,
      );

      if (response.success && response.data != null) {
        debugPrint('✅ Category news fetched successfully');
        return _parseNewsResponse(response.data);
      } else {
        throw Exception(response.error ?? 'Failed to fetch category news');
      }
    } catch (e) {
      debugPrint('❌ Error fetching category news: $e');
      rethrow;
    }
  }
  
  /// Fetch news by multiple categories from backend
  /// [categories] - List of category names (e.g., ['business', 'sports'])
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch
  /// [page] - Page number for pagination
  /// 
  /// API Format: /getActiveNewsMobile?category=top&category=lifestyle
  Future<NewsResponse> fetchNewsByCategories({
    required List<String> categories,
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      debugPrint('📰 Fetching news by multiple categories from backend...');
      // Convert language code to full language name for backend API
      final languageName = _convertLanguageCodeToName(language);
      debugPrint(
        '   Categories: ${categories.join(", ")}, Language: $languageName, Limit: $limit, Page: $page',
      );
      
      // Build base query parameters
      final queryParameters = <String, dynamic>{
        if (languageName != null && languageName.isNotEmpty)
          'language': languageName,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Get bearer token if user is logged in
      String? bearerToken;
      if (_userService.isLoggedIn) {
        bearerToken = _userService.getToken();
      }

      // Call backend API using newsByCategory endpoint with multiple category params
      final response = await _apiService.getWithMultipleParams(
        'news',
        'newsByCategory',
        queryParameters: queryParameters,
        multiValueParams: {'category': categories},
        bearerToken: bearerToken,
      );

      if (response.success && response.data != null) {
        debugPrint('✅ Multi-category news fetched successfully');
        return _parseNewsResponse(response.data);
      } else {
        throw Exception(response.error ?? 'Failed to fetch category news');
      }
    } catch (e) {
      debugPrint('❌ Error fetching multi-category news: $e');
      rethrow;
    }
  }

  /// Search news from backend
  /// Uses the same endpoint as breaking news but with search parameter
  /// API: https://api.newson.app/api/latestnews/getActiveNewsMobile?language=tamil&limit=10&page=1&search=keyword
  /// [query] - Search query
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 50)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> searchNews({
    required String query,
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      debugPrint('📰 Searching news from backend...');
      // Convert language code to full language name for backend API
      final languageName = _convertLanguageCodeToName(language);
      debugPrint(
        '   Search Query: "$query", Language Code: $language → Language Name: $languageName, Limit: $limit, Page: $page',
      );

      // Build query parameters with 'search' parameter (not 'q')
      final queryParameters = <String, String>{
        'search': query, // Backend API uses 'search' parameter
        if (languageName != null && languageName.isNotEmpty)
          'language': languageName,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Get bearer token if user is logged in
      String? bearerToken;
      if (_userService.isLoggedIn) {
        bearerToken = _userService.getToken();
      }

      // Call backend API using the same endpoint as breaking news
      // The endpoint is: api/latestnews/getActiveNewsMobile
      final response = await _apiService.get(
        'news',
        'breakingNews', // Maps to "api/latestnews/getActiveNewsMobile"
        queryParameters: queryParameters,
        bearerToken: bearerToken,
      );

      if (response.success && response.data != null) {
        debugPrint('✅ News search completed successfully');
        return _parseNewsResponse(response.data);
      } else {
        throw Exception(response.error ?? 'Failed to search news');
      }
    } catch (e) {
      debugPrint('❌ Error searching news: $e');
      rethrow;
    }
  }

  /// Parse backend API response to NewsResponse
  /// Expected response format:
  /// {
  ///   "message": "success",
  ///   "pagination": {
  ///     "total": 3060,
  ///     "page": 1,
  ///     "limit": 50,
  ///     "totalPages": 62
  ///   },
  ///   "data": [...]
  /// }
  NewsResponse _parseNewsResponse(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        // Extract articles from 'data' array
        List<dynamic> results = [];
        if (data.containsKey('data') && data['data'] is List) {
          results = data['data'] as List;
        } else if (data.containsKey('results') && data['results'] is List) {
          results = data['results'] as List;
        } else if (data.containsKey('news') && data['news'] is List) {
          results = data['news'] as List;
        }

        // Extract pagination info
        int totalResults = 0;
        int currentPage = 1;
        int totalPages = 1;
        String? nextPage;

        if (data.containsKey('pagination') && data['pagination'] is Map) {
          final pagination = data['pagination'] as Map<String, dynamic>;
          totalResults = pagination['total'] as int? ?? results.length;
          currentPage = pagination['page'] as int? ?? 1;
          totalPages = pagination['totalPages'] as int? ?? 1;

          // Calculate nextPage token if there are more pages
          if (currentPage < totalPages) {
            nextPage = (currentPage + 1).toString();
          }
        } else {
          // Fallback: try to get from root level
          totalResults =
              data['total'] as int? ??
              data['totalResults'] as int? ??
              data['total_results'] as int? ??
              results.length;

          // Try to get nextPage from various possible locations
          if (data.containsKey('nextPage')) {
            nextPage = data['nextPage']?.toString();
          } else if (data.containsKey('next_page')) {
            nextPage = data['next_page']?.toString();
          }
        }

        // Get status/message
        final status =
            data['message'] as String? ??
            data['status'] as String? ??
            'success';

        // Parse articles
        final articles =
            results
                .map((item) {
                  try {
                    return NewsArticle.fromJson(item as Map<String, dynamic>);
                  } catch (e) {
                    debugPrint('⚠️ Error parsing article: $e');
                    debugPrint('Article data: $item');
                    return null;
                  }
                })
                .whereType<NewsArticle>()
                .toList();

        debugPrint('✅ Parsed ${articles.length} articles from backend API');
        debugPrint('   Total: $totalResults, Page: $currentPage/$totalPages');

        return NewsResponse(
          status: status,
          totalResults: totalResults,
          results: articles,
          nextPage: nextPage,
        );
      } else {
        throw Exception(
          'Invalid response format from backend API: Expected Map, got ${data.runtimeType}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing news response: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Response data: $data');
      rethrow;
    }
  }
}
