import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/auth_navigation_helper.dart';
import '../data/models/news_article.dart';
import '../data/repositories/news_repository.dart';
import '../data/services/bookmark_api_service.dart';
import '../data/services/interaction_service.dart';
import '../data/services/news_audio_cache_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/user_service.dart';

/// Provider for managing bookmarks with API sync and offline caching
class BookmarkProvider with ChangeNotifier {
  final NewsRepository _repository;
  BookmarkApiService? _bookmarkApiService;
  final UserService _userService = UserService();

  BookmarkProvider({NewsRepository? repository})
      : _repository = repository ?? NewsRepository(apiKey: '');

  BookmarkApiService? get _bookmarkApi {
    try {
      return _bookmarkApiService ??= BookmarkApiService();
    } catch (_) {
      return null;
    }
  }

  BookmarkApiService get _requireBookmarkApi {
    final api = _bookmarkApi;
    if (api == null) {
      throw StateError('Bookmark API unavailable');
    }
    return api;
  }

  List<NewsArticle> _bookmarks = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalBookmarks = 0;
  int _loadGeneration = 0;

  /// Recently removed Mongo IDs — ignore them if a stale list response still
  /// contains them (common race: remove → refresh → old server/cache list).
  final Set<String> _removedNewsIds = <String>{};

  // Getters
  List<NewsArticle> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get bookmarksCount => _bookmarks.length;
  bool get hasBookmarks => _bookmarks.isNotEmpty;
  bool get hasMore => _hasMore;
  int get totalBookmarks => _totalBookmarks;

  /// Load all bookmarks from API (with offline cache support)
  Future<void> loadBookmarks({
    bool refresh = false,
    int page = 1,
    bool forceNetwork = false,
  }) async {
    if (!_userService.isLoggedIn) {
      debugPrint('⚠️ User not authenticated, loading from local cache only');
      _loadBookmarksFromCache();
      return;
    }

    final generation = ++_loadGeneration;

    try {
      _isLoading = true;
      _error = null;

      if (refresh || forceNetwork) {
        _currentPage = 1;
        _hasMore = true;
        // Keep current list visible until network returns (no flash of stale cache).
        if (!forceNetwork && _bookmarks.isEmpty) {
          final cached = StorageService.getBookmarkListCache();
          if (cached.isNotEmpty) {
            _bookmarks = _filterRemoved(cached);
            notifyListeners();
          }
        } else if (refresh) {
          notifyListeners();
        }
      } else {
        _currentPage = page;
        if (_currentPage == 1 && _bookmarks.isEmpty) {
          final cachedBookmarks = StorageService.getBookmarkListCache();
          if (cachedBookmarks.isNotEmpty) {
            _bookmarks = _filterRemoved(cachedBookmarks);
            notifyListeners();
          }
        }
      }

      notifyListeners();

      try {
        final response = await _requireBookmarkApi.getBookmarkList(
          page: _currentPage,
          limit: 20,
        );

        if (generation != _loadGeneration) {
          debugPrint('🔖 Ignoring stale bookmark load (gen $generation)');
          return;
        }

        final filtered = _filterRemoved(response.data);

        if (_currentPage == 1) {
          _bookmarks = filtered;
        } else {
          _bookmarks.addAll(filtered);
        }

        _hasMore = response.pagination.hasMore;
        _totalBookmarks = response.pagination.total;
        _currentPage = response.pagination.page;

        await StorageService.saveBookmarkListCache(_bookmarks);
        // Keep Hive in sync with authoritative list (prevents resurrected icons).
        await StorageService.replaceAllBookmarks(_bookmarks);

        unawaited(
          NewsAudioCacheService.instance.prefetchArticles(
            _bookmarks,
            maxUrls: 40,
          ),
        );

        _isLoading = false;
        debugPrint('✅ Bookmark list fetched: ${_bookmarks.length} items');
        notifyListeners();
      } catch (apiError) {
        if (generation != _loadGeneration) return;
        if (_bookmarks.isNotEmpty) {
          debugPrint('⚠️ API fetch failed, using in-memory bookmarks: $apiError');
          _isLoading = false;
          _error = null;
          notifyListeners();
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Error loading bookmarks: $e');
      notifyListeners();
    }
  }

  List<NewsArticle> _filterRemoved(List<NewsArticle> list) {
    if (_removedNewsIds.isEmpty) return list;
    return list.where((a) {
      final id = a.newsId?.trim();
      if (id == null || id.isEmpty) return true;
      return !_removedNewsIds.contains(id);
    }).toList();
  }

  void _loadBookmarksFromCache() {
    try {
      _isLoading = true;
      notifyListeners();

      _bookmarks = _filterRemoved(StorageService.getBookmarkListCache());
      if (_bookmarks.isEmpty) {
        _bookmarks = _filterRemoved(StorageService.getAllBookmarks());
      }

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

  Future<void> loadMoreBookmarks() async {
    if (_isLoading || !_hasMore) return;
    await loadBookmarks(page: _currentPage + 1);
  }

  String? _bookmarkApiNewsId(NewsArticle article) {
    final id = article.newsId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool isBookmarked(NewsArticle article) {
    final mongoId = article.newsId?.trim();
    if (mongoId != null &&
        mongoId.isNotEmpty &&
        _removedNewsIds.contains(mongoId)) {
      return false;
    }
    final articleKey = article.articleId ?? article.title;
    return _bookmarks.any((a) {
      if (mongoId != null &&
          mongoId.isNotEmpty &&
          a.newsId != null &&
          a.newsId == mongoId) {
        return true;
      }
      return (a.articleId ?? a.title) == articleKey;
    });
  }

  Future<void> _purgeLocal(NewsArticle article, String newsId) async {
    _removedNewsIds.add(newsId);
    _bookmarks.removeWhere((a) {
      final aId = a.newsId?.trim();
      if (aId != null && aId == newsId) return true;
      return (a.articleId ?? a.title) == (article.articleId ?? article.title);
    });
    await StorageService.removeBookmarkForArticle(article);
    await StorageService.removeBookmark(newsId);
    await StorageService.saveBookmarkListCache(_bookmarks);
  }

  Future<bool> toggleBookmark(NewsArticle article) async {
    final currentlyBookmarked = isBookmarked(article);

    if (!_userService.isLoggedIn) {
      debugPrint('🔖 Bookmark requires login — opening AuthScreen');
      navigateToLoginForAccountFeatureGlobal();
      return currentlyBookmarked;
    }

    try {
      final newsId = _bookmarkApiNewsId(article);
      if (newsId == null) {
        throw Exception(
          'Cannot bookmark: article has no Mongo _id (newsId). '
          'Do not use article_id for bookmark APIs.',
        );
      }

      debugPrint('🔖 ToggleBookmark - newsId (_id): $newsId');

      if (currentlyBookmarked) {
        await _requireBookmarkApi.removeBookmark(newsId);
        await _purgeLocal(article, newsId);
        notifyListeners();
        debugPrint('✅ Bookmark removed');
        return false;
      } else {
        _removedNewsIds.remove(newsId);
        await _requireBookmarkApi.addBookmark(newsId);

        final bookmarkedArticle = article.copyWith(
          isBookmarked: true,
          bookmarkedAt: DateTime.now(),
          newsId: newsId,
        );
        _bookmarks.insert(0, bookmarkedArticle);
        await StorageService.addBookmark(bookmarkedArticle);
        await StorageService.saveBookmarkListCache(_bookmarks);

        notifyListeners();
        debugPrint('✅ Bookmark added');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');
      // Do NOT fall back to local-only bookmark when logged in — that causes
      // "removed then reappears" when the next list sync hits the server.
      rethrow;
    }
  }

  /// V2 Reader / V2 Article Detail bookmark — local UI + V2 interaction only.
  ///
  /// Persists engagement via [InteractionService.ensureBookmarkTracked]
  /// (`POST /api/interaction` on the V2 host). Never calls
  /// `api.newson.app` `/api/bookmark/addBookmark` or other V1 bookmark APIs.
  Future<bool> toggleBookmarkV2(NewsArticle article) async {
    final currentlyBookmarked = isBookmarked(article);

    if (!_userService.isLoggedIn) {
      debugPrint('🔖 V2 bookmark requires login — opening AuthScreen');
      navigateToLoginForAccountFeatureGlobal();
      return currentlyBookmarked;
    }

    final newsId = (article.newsId ?? article.articleId)?.trim();
    if (newsId == null || newsId.isEmpty) {
      throw Exception('Cannot bookmark: missing V2 article id');
    }

    final interactions = InteractionService();

    if (currentlyBookmarked) {
      await _purgeLocal(article, newsId);
      interactions.clearBookmarkDedupe(article);
      notifyListeners();
      debugPrint('✅ V2 bookmark removed (local + interaction dedupe cleared)');
      return false;
    }

    // Optimistic local UI, then V2 interaction persistence.
    _removedNewsIds.remove(newsId);
    final bookmarkedArticle = article.copyWith(
      isBookmarked: true,
      bookmarkedAt: DateTime.now(),
      newsId: newsId,
      articleId: article.articleId ?? newsId,
    );
    _bookmarks.insert(0, bookmarkedArticle);
    notifyListeners();

    try {
      await StorageService.addBookmark(bookmarkedArticle);
      await StorageService.saveBookmarkListCache(_bookmarks);
      await interactions.ensureBookmarkTracked(bookmarkedArticle);
      debugPrint('✅ V2 bookmark added (local + /api/interaction)');
      return true;
    } catch (e) {
      debugPrint('❌ V2 bookmark persistence failed — rolling back: $e');
      await _purgeLocal(article, newsId);
      notifyListeners();
      rethrow;
    }
  }

  // ignore: unused_element
  Future<bool> _toggleBookmarkLocal(NewsArticle article) async {
    try {
      final isBookmarked = await _repository.toggleBookmark(article);

      if (isBookmarked) {
        final bookmarkedArticle = article.copyWith(
          isBookmarked: true,
          bookmarkedAt: DateTime.now(),
        );
        _bookmarks.insert(0, bookmarkedArticle);
      } else {
        await StorageService.removeBookmarkForArticle(article);
        final key = article.articleId ?? article.title;
        _bookmarks.removeWhere((a) => (a.articleId ?? a.title) == key);
      }

      await StorageService.saveBookmarkListCache(_bookmarks);
      notifyListeners();
      return isBookmarked;
    } catch (e) {
      debugPrint('❌ Error toggling bookmark locally: $e');
      rethrow;
    }
  }

  Future<void> removeBookmark(NewsArticle article) async {
    final newsId = _bookmarkApiNewsId(article);
    if (newsId == null || newsId.isEmpty) {
      throw Exception(
        'Cannot remove bookmark: article has no Mongo _id (newsId).',
      );
    }

    try {
      if (_userService.isLoggedIn) {
        await _requireBookmarkApi.removeBookmark(newsId);
      }
      await _purgeLocal(article, newsId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      await _purgeLocal(article, newsId);
      notifyListeners();
      rethrow;
    }
  }

  /// Clear all bookmarks — uses bulk DELETE /api/bookmark/removeAllBookmarks,
  /// then falls back to sequential single removes if bulk is unavailable.
  Future<void> clearAllBookmarks() async {
    final snapshot = List<NewsArticle>.from(_bookmarks);
    try {
      if (_userService.isLoggedIn) {
        var bulkOk = false;
        try {
          bulkOk = await _requireBookmarkApi.removeAllBookmarks();
        } catch (e) {
          debugPrint('⚠️ Bulk clear failed, falling back to one-by-one: $e');
          bulkOk = false;
        }

        if (bulkOk) {
          for (final article in snapshot) {
            final newsId = _bookmarkApiNewsId(article);
            if (newsId != null) _removedNewsIds.add(newsId);
          }
        } else {
          for (final article in snapshot) {
            final newsId = _bookmarkApiNewsId(article);
            if (newsId == null) continue;
            try {
              await _requireBookmarkApi.removeBookmark(newsId);
              _removedNewsIds.add(newsId);
            } catch (e) {
              debugPrint('⚠️ Failed to remove bookmark $newsId: $e');
            }
          }
        }
      }

      _bookmarks = [];
      _totalBookmarks = 0;
      _hasMore = false;
      await StorageService.clearAllBookmarks();
      await StorageService.saveBookmarkListCache([]);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing bookmarks: $e');
      rethrow;
    }
  }

  List<NewsArticle> getBookmarksByCategory(String category) {
    return _bookmarks.where((article) {
      return article.category?.contains(category) ?? false;
    }).toList();
  }

  List<NewsArticle> searchBookmarks(String query) {
    if (query.isEmpty) return _bookmarks;

    final lowerQuery = query.toLowerCase();
    return _bookmarks.where((article) {
      return article.title.toLowerCase().contains(lowerQuery) ||
          (article.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
