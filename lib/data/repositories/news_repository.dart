import '../models/news_article.dart';
import '../models/news_response.dart';
import '../services/news_api_service.dart';
import '../services/storage_service.dart';

/// Repository layer for news data management
/// Handles both API calls and local storage
class NewsRepository {
  final NewsApiService _apiService;

  NewsRepository({required String apiKey, NewsApiService? apiService})
      : _apiService = apiService ?? NewsApiService(apiKey: apiKey);

  /// Fetch news with optional filters
  Future<NewsResponse> fetchNews({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) async {
    try {
      final response = await _apiService.fetchNews(
        category: category,
        country: country,
        language: language,
        query: query,
        nextPage: nextPage,
      );

      // Update bookmark status for fetched articles
      final updatedResults = response.results.map((article) {
        final key = article.articleId ?? article.title;
        final isBookmarked = StorageService.isBookmarked(key);
        return article.copyWith(isBookmarked: isBookmarked);
      }).toList();

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

  /// Fetch news by category
  Future<NewsResponse> fetchNewsByCategory(
    String category, {
    String? language,
    String? nextPage,
  }) async {
    return fetchNews(
      category: category,
      language: language,
      nextPage: nextPage,
    );
  }

  /// Search news
  Future<NewsResponse> searchNews(
    String query, {
    String? language,
    String? nextPage,
  }) async {
    return fetchNews(
      query: query,
      language: language,
      nextPage: nextPage,
    );
  }

  /// Fetch breaking news
  Future<NewsResponse> fetchBreakingNews({
    String? language,
    String? nextPage,
  }) async {
    return _apiService.fetchBreakingNews(
      language: language,
      nextPage: nextPage,
    );
  }

  /// Fetch archive news by date range
  /// fromDate and toDate should be in format: 'YYYY-MM-DD'
  Future<NewsResponse> fetchArchiveNews({
    required String fromDate,
    String? toDate,
    String? query,
    String? category,
    String? language,
    String? nextPage,
  }) async {
    try {
      final response = await _apiService.fetchArchiveNews(
        fromDate: fromDate,
        toDate: toDate,
        query: query,
        category: category,
        language: language,
        nextPage: nextPage,
      );

      // Update bookmark status for fetched articles
      final updatedResults = response.results.map((article) {
        final key = article.articleId ?? article.title;
        final isBookmarked = StorageService.isBookmarked(key);
        return article.copyWith(isBookmarked: isBookmarked);
      }).toList();

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
    _apiService.dispose();
  }
}
