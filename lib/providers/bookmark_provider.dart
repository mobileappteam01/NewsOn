import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/repositories/news_repository.dart';

/// Provider for managing bookmarks
class BookmarkProvider with ChangeNotifier {
  final NewsRepository _repository;

  BookmarkProvider({NewsRepository? repository})
    : _repository = repository ?? NewsRepository(apiKey: '');

  List<NewsArticle> _bookmarks = [];
  bool _isLoading = false;

  // Getters
  List<NewsArticle> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  int get bookmarksCount => _bookmarks.length;
  bool get hasBookmarks => _bookmarks.isNotEmpty;

  /// Load all bookmarks
  Future<void> loadBookmarks() async {
    _isLoading = true;
    notifyListeners();

    _bookmarks = _repository.getBookmarkedArticles();
    // Sort by bookmarked date (most recent first)
    _bookmarks.sort((a, b) {
      if (a.bookmarkedAt == null) return 1;
      if (b.bookmarkedAt == null) return -1;
      return b.bookmarkedAt!.compareTo(a.bookmarkedAt!);
    });

    _isLoading = false;
    notifyListeners();
  }

  /// Check if article is bookmarked
  bool isBookmarked(NewsArticle article) {
    final key = article.articleId ?? article.title;
    return _bookmarks.any((a) => (a.articleId ?? a.title) == key);
  }

  /// Toggle bookmark
  Future<bool> toggleBookmark(NewsArticle article) async {
    try {
      final isBookmarked = await _repository.toggleBookmark(article);
      await loadBookmarks();
      return isBookmarked;
    } catch (e) {
      rethrow;
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(NewsArticle article) async {
    try {
      await _repository.removeBookmark(article);
      await loadBookmarks();
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    try {
      await _repository.clearAllBookmarks();
      await loadBookmarks();
    } catch (e) {
      rethrow;
    }
  }

  /// Filter bookmarks by category
  List<NewsArticle> getBookmarksByCategory(String category) {
    return _bookmarks.where((article) {
      return article.category?.contains(category) ?? false;
    }).toList();
  }

  /// Search bookmarks
  List<NewsArticle> searchBookmarks(String query) {
    if (query.isEmpty) return _bookmarks;

    final lowerQuery = query.toLowerCase();
    return _bookmarks.where((article) {
      return article.title.toLowerCase().contains(lowerQuery) ||
          (article.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
