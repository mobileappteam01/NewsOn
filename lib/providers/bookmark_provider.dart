import 'package:flutter/foundation.dart';
import '../data/models/news_article.dart';
import '../data/repositories/news_repository.dart';
import '../data/services/bookmark_api_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/user_service.dart';

/// Provider for managing bookmarks with API sync and offline caching
class BookmarkProvider with ChangeNotifier {
  final NewsRepository _repository;
  final BookmarkApiService _bookmarkApiService = BookmarkApiService();
  final UserService _userService = UserService();

  BookmarkProvider({NewsRepository? repository})
    : _repository = repository ?? NewsRepository(apiKey: '');

  List<NewsArticle> _bookmarks = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalBookmarks = 0;

  // Getters
  List<NewsArticle> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get bookmarksCount => _bookmarks.length;
  bool get hasBookmarks => _bookmarks.isNotEmpty;
  bool get hasMore => _hasMore;
  int get totalBookmarks => _totalBookmarks;

  /// Load all bookmarks from API (with offline cache support)
  Future<void> loadBookmarks({bool refresh = false, int page = 1}) async {
    // Check if user is authenticated
    if (!_userService.isLoggedIn) {
      debugPrint('⚠️ User not authenticated, loading from local cache only');
      _loadBookmarksFromCache();
      return;
    }

    try {
      _isLoading = true;
      _error = null;

      if (refresh) {
        _currentPage = 1;
        _bookmarks = [];
        _hasMore = true;
      } else {
        _currentPage = page;
      }

      // Step 1: Load from cache first (for instant offline display)
      if (_currentPage == 1 && _bookmarks.isEmpty) {
        final cachedBookmarks = StorageService.getBookmarkListCache();
        if (cachedBookmarks.isNotEmpty) {
          _bookmarks = cachedBookmarks;
          notifyListeners(); // Show cached data immediately
          debugPrint(
            "📦 Loaded ${cachedBookmarks.length} bookmarks from cache",
          );
        }
      }

      notifyListeners();

      // Step 2: Try to fetch from API
      try {
        final response = await _bookmarkApiService.getBookmarkList(
          page: _currentPage,
          limit: 20,
        );

        if (_currentPage == 1) {
          _bookmarks = response.data;
        } else {
          _bookmarks.addAll(response.data);
        }

        _hasMore = response.pagination.hasMore;
        _totalBookmarks = response.pagination.total;
        _currentPage = response.pagination.page;

        // Cache bookmark list for offline use
        await StorageService.saveBookmarkListCache(_bookmarks);

        // Update local storage for backward compatibility
        for (final article in _bookmarks) {
          await StorageService.addBookmark(article);
        }

        _isLoading = false;
        debugPrint("✅ Bookmark list fetched: ${_bookmarks.length} items");
        notifyListeners();
      } catch (apiError) {
        // If API fails and we have cached data, keep using it
        if (_bookmarks.isNotEmpty) {
          debugPrint("⚠️ API fetch failed, using cached bookmarks: $apiError");
          _isLoading = false;
          _error = null; // Don't show error if we have cached data
          notifyListeners();
        } else {
          // No cached data, show error
          rethrow;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (_bookmarks.isEmpty) {
        _bookmarks = [];
      }
      debugPrint("❌ Error loading bookmarks: $e");
      notifyListeners();
    }
  }

  /// Load bookmarks from local cache only (for offline/unauthenticated users)
  void _loadBookmarksFromCache() {
    try {
      _isLoading = true;
      notifyListeners();

      _bookmarks = StorageService.getBookmarkListCache();
      if (_bookmarks.isEmpty) {
        // Fallback to old storage method
        _bookmarks = StorageService.getAllBookmarks();
      }

      // Sort by bookmarked date (most recent first)
      _bookmarks.sort((a, b) {
        if (a.bookmarkedAt == null) return 1;
        if (b.bookmarkedAt == null) return -1;
        return b.bookmarkedAt!.compareTo(a.bookmarkedAt!);
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _bookmarks = [];
      notifyListeners();
    }
  }

  /// Load more bookmarks (pagination)
  Future<void> loadMoreBookmarks() async {
    if (_isLoading || !_hasMore) return;
    await loadBookmarks(page: _currentPage + 1);
  }

  /// Check if article is bookmarked
  bool isBookmarked(NewsArticle article) {
    final key = article.articleId ?? article.title;
    return _bookmarks.any((a) => (a.articleId ?? a.title) == key);
  }

  /// Toggle bookmark (syncs with API)
  Future<bool> toggleBookmark(NewsArticle article) async {
    try {
      debugPrint("theee article detailsss : ${article.toJson()}");
      // For API calls, use article_id (the actual news article ID), not _id (bookmark record ID)
      // newsId might be _id from bookmark list, but we need article_id for the API
      final newsId = article.newsId ?? article.articleId ?? article.title;

      debugPrint('🔖 ToggleBookmark - newsId: $newsId');
      debugPrint('🔖 ToggleBookmark - article.newsId: ${article.newsId}');
      debugPrint('🔖 ToggleBookmark - article.articleId: ${article.articleId}');
      final currentlyBookmarked = isBookmarked(article);

      // Check if user is authenticated
      if (!_userService.isLoggedIn) {
        // Use local storage only
        return await _toggleBookmarkLocal(article);
      }

      if (currentlyBookmarked) {
        // Remove bookmark via API
        await _bookmarkApiService.removeBookmark(newsId);

        // Update local state immediately - match by newsId, articleId, or title
        _bookmarks.removeWhere(
          (a) =>
              (a.newsId ?? a.articleId ?? a.title) == newsId ||
              (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );

        // Remove from local storage - use articleId or title as key
        final storageKey = article.articleId ?? article.title;
        await StorageService.removeBookmark(storageKey);

        // Update cache
        await StorageService.saveBookmarkListCache(_bookmarks);

        notifyListeners();
        debugPrint('✅ Bookmark removed');
        return false;
      } else {
        // Add bookmark via API
        await _bookmarkApiService.addBookmark(newsId);

        // Update local state immediately
        final bookmarkedArticle = article.copyWith(
          isBookmarked: true,
          bookmarkedAt: DateTime.now(),
        );
        _bookmarks.insert(0, bookmarkedArticle); // Add to top

        // Save to local storage
        await StorageService.addBookmark(bookmarkedArticle);

        // Update cache
        await StorageService.saveBookmarkListCache(_bookmarks);

        notifyListeners();
        debugPrint('✅ Bookmark added');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');

      // Fallback to local storage if API fails
      if (!isBookmarked(article)) {
        return await _toggleBookmarkLocal(article);
      }
      rethrow;
    }
  }

  /// Toggle bookmark using local storage only (for offline/unauthenticated)
  Future<bool> _toggleBookmarkLocal(NewsArticle article) async {
    try {
      final isBookmarked = await _repository.toggleBookmark(article);

      // Update local state
      if (isBookmarked) {
        final bookmarkedArticle = article.copyWith(
          isBookmarked: true,
          bookmarkedAt: DateTime.now(),
        );
        _bookmarks.insert(0, bookmarkedArticle);
      } else {
        final key = article.articleId ?? article.title;
        _bookmarks.removeWhere((a) => (a.articleId ?? a.title) == key);
      }

      // Update cache
      await StorageService.saveBookmarkListCache(_bookmarks);

      notifyListeners();
      return isBookmarked;
    } catch (e) {
      debugPrint('❌ Error toggling bookmark locally: $e');
      rethrow;
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(NewsArticle article) async {
    try {
      // For API calls, use article_id (the actual news article ID), not _id (bookmark record ID)
      // newsId might be _id from bookmark list, but we need article_id for the API
      final newsId = article.articleId ?? article.newsId ?? article.title;

      debugPrint('🗑️ RemoveBookmark - newsId: $newsId');
      debugPrint(
        '🗑️ RemoveBookmark - article.newsId: ${article.newsId} (from _id)',
      );
      debugPrint(
        '🗑️ RemoveBookmark - article.articleId: ${article.articleId} (actual news ID)',
      );
      debugPrint('🗑️ RemoveBookmark - article.title: ${article.title}');

      // Validate newsId
      if (newsId.isEmpty) {
        throw Exception('newsId cannot be empty for removing bookmark');
      }

      // Check if user is authenticated
      if (_userService.isLoggedIn) {
        await _bookmarkApiService.removeBookmark(newsId);
      }

      // Update local state - match by newsId, articleId, or title
      _bookmarks.removeWhere(
        (a) =>
            (a.newsId ?? a.articleId ?? a.title) == newsId ||
            (a.articleId ?? a.title) == (article.articleId ?? article.title),
      );

      // Remove from local storage - use articleId or title as key
      final storageKey = article.articleId ?? article.title;
      await StorageService.removeBookmark(storageKey);

      // Update cache
      await StorageService.saveBookmarkListCache(_bookmarks);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      // Still remove from local even if API fails
      final storageKey = article.articleId ?? article.title;
      _bookmarks.removeWhere(
        (a) =>
            (a.newsId ?? a.articleId ?? a.title) ==
                (article.newsId ?? article.articleId ?? article.title) ||
            (a.articleId ?? a.title) == storageKey,
      );
      await StorageService.removeBookmark(storageKey);
      await StorageService.saveBookmarkListCache(_bookmarks);
      notifyListeners();
      rethrow;
    }
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    try {
      // Note: API might not support bulk delete, so we'll remove one by one
      // For now, just clear locally and let user re-sync
      _bookmarks = [];
      await StorageService.clearAllBookmarks();
      await StorageService.saveBookmarkListCache([]);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing bookmarks: $e');
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
