import '../models/news_article.dart';
import '../models/news_response.dart';
import '../services/backend_news_service.dart';
import '../services/storage_service.dart';

/// Repository layer for news data management
/// Handles both API calls and local storage
/// Now uses BackendNewsService instead of NewsApiService
class NewsRepository {
  final BackendNewsService _backendService;

  NewsRepository({required String apiKey, BackendNewsService? backendService})
    : _backendService = backendService ?? BackendNewsService();

  /// Fetch news with optional filters (deprecated - use specific methods)
  /// This method is kept for backward compatibility but should use specific methods
  Future<NewsResponse> fetchNews({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) async {
    // If query is provided, use search
    if (query != null && query.isNotEmpty) {
      return searchNews(query, language: language, limit: 50, page: 1);
    }
    // If category is provided, use category fetch
    if (category != null && category.isNotEmpty) {
      return fetchNewsByCategory(
        category,
        language: language,
        limit: 50,
        page: 1,
      );
    }
    // Otherwise, use breaking news
    return fetchBreakingNews(language: language, limit: 50, page: 1);
  }

  /// Fetch news by category
  /// [category] - Category name (e.g., 'business', 'sports')
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 50)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchNewsByCategory(
    String category, {
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final response = await _backendService.fetchNewsByCategory(
        category: category,
        language: language,
        limit: limit,
        page: page,
      );

      // Update bookmark status for fetched articles
      final updatedResults =
          response.results.map((article) {
            final key = article.articleId ?? article.title;
            final isBookmarked = StorageService.isBookmarked(key);
            return article.copyWith(isBookmarked: isBookmarked);
          }).toList();

      // Cache articles for offline use (only first page)
      if (page == 1) {
        await StorageService.saveArticlesCache(updatedResults);
      }

      return NewsResponse(
        status: response.status,
        totalResults: response.totalResults,
        results: updatedResults,
        nextPage: response.nextPage,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch news by multiple categories
  /// [categories] - List of category names (e.g., ['business', 'sports'])
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 50)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchNewsByCategories(
    List<String> categories, {
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final response = await _backendService.fetchNewsByCategories(
        categories: categories,
        language: language,
        limit: limit,
        page: page,
      );

      // Update bookmark status for fetched articles
      final updatedResults =
          response.results.map((article) {
            final key = article.articleId ?? article.title;
            final isBookmarked = StorageService.isBookmarked(key);
            return article.copyWith(isBookmarked: isBookmarked);
          }).toList();

      // Cache articles for offline use (only first page)
      if (page == 1) {
        await StorageService.saveArticlesCache(updatedResults);
      }

      return NewsResponse(
        status: response.status,
        totalResults: response.totalResults,
        results: updatedResults,
        nextPage: response.nextPage,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Search news
  /// [query] - Search query
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 50)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> searchNews(
    String query, {
    String? language,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final response = await _backendService.searchNews(
        query: query,
        language: language,
        limit: limit,
        page: page,
      );

      // Update bookmark status for fetched articles
      final updatedResults =
          response.results.map((article) {
            final key = article.articleId ?? article.title;
            final isBookmarked = StorageService.isBookmarked(key);
            return article.copyWith(isBookmarked: isBookmarked);
          }).toList();

      // Cache search results for offline use (only first page)
      if (page == 1) {
        await StorageService.saveArticlesCache(updatedResults);
      }

      return NewsResponse(
        status: response.status,
        totalResults: response.totalResults,
        results: updatedResults,
        nextPage: response.nextPage,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch breaking news
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 10 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchBreakingNews({
    String? language,
    int limit = 10,
    int page = 1,
  }) async {
    try {
      final response = await _backendService.fetchBreakingNews(
        language: language,
        limit: limit,
        page: page,
      );

      // Update bookmark status for fetched articles
      final updatedResults =
          response.results.map((article) {
            final key = article.articleId ?? article.title;
            final isBookmarked = StorageService.isBookmarked(key);
            return article.copyWith(isBookmarked: isBookmarked);
          }).toList();

      // Cache breaking news for offline use (only first page)
      if (page == 1) {
        await StorageService.saveBreakingNewsCache(updatedResults);
      }

      return NewsResponse(
        status: response.status,
        totalResults: response.totalResults,
        results: updatedResults,
        nextPage: response.nextPage,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch today's news (archive/news by date)
  /// [date] - Date in format 'YYYY-MM-DD' (optional, defaults to today)
  /// [language] - Language code (e.g., 'en', 'ta', 'hi')
  /// [limit] - Number of items to fetch (default: 5 for home page, 50 for View All)
  /// [page] - Page number for pagination (default: 1)
  Future<NewsResponse> fetchTodayNews({
    String? date,
    String? language,
    int limit = 5,
    int page = 1,
  }) async {
    try {
      final response = await _backendService.fetchTodayNews(
        date: date,
        language: language,
        limit: limit,
        page: page,
      );

      // Update bookmark status for fetched articles
      final updatedResults =
          response.results.map((article) {
            final key = article.articleId ?? article.title;
            final isBookmarked = StorageService.isBookmarked(key);
            return article.copyWith(isBookmarked: isBookmarked);
          }).toList();

      // Cache today's news for offline use (only first page)
      if (page == 1) {
        await StorageService.saveTodayNewsCache(updatedResults);
      }

      return NewsResponse(
        status: response.status,
        totalResults: response.totalResults,
        results: updatedResults,
        nextPage: response.nextPage,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch archive news by date range (kept for backward compatibility)
  /// fromDate and toDate should be in format: 'YYYY-MM-DD'
  Future<NewsResponse> fetchArchiveNews({
    required String fromDate,
    String? toDate,
    String? query,
    String? category,
    String? language,
    String? nextPage,
  }) async {
    // Use todayNews endpoint with date parameter
    return fetchTodayNews(
      date: fromDate,
      language: language,
      limit: 50,
      page: 1,
    );
  }

  /// Toggle bookmark status
  Future<bool> toggleBookmark(NewsArticle article) async {
    try {
      final key = article.articleId ?? article.title;
      final isCurrentlyBookmarked = StorageService.isBookmarked(key);

      if (isCurrentlyBookmarked) {
        await StorageService.removeBookmark(key);
        return false;
      } else {
        await StorageService.addBookmark(article);
        return true;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all bookmarked articles
  List<NewsArticle> getBookmarkedArticles() {
    return StorageService.getAllBookmarks();
  }

  /// Check if article is bookmarked
  bool isArticleBookmarked(NewsArticle article) {
    final key = article.articleId ?? article.title;
    return StorageService.isBookmarked(key);
  }

  /// Remove bookmark
  Future<void> removeBookmark(NewsArticle article) async {
    final key = article.articleId ?? article.title;
    await StorageService.removeBookmark(key);
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    await StorageService.clearAllBookmarks();
  }

  /// Get bookmarks count
  int getBookmarksCount() {
    return StorageService.getBookmarksCount();
  }

  /// Dispose resources
  void dispose() {
    // BackendNewsService doesn't need disposal
  }
}
