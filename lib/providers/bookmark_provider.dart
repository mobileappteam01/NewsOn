import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/auth_navigation_helper.dart';
import '../features/bookmarks/domain/bookmark_list_state.dart';
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

  /// Last list load used the V2 bookmark route (not the V1 catalog).
  bool _v2List = false;

  /// Recently removed Mongo IDs — V1 list race only.
  /// A successful V2 refresh replaces the list from the API and does not
  /// consult this set.
  final Set<String> _removedNewsIds = <String>{};

  final BookmarkToggleGuard _toggleGuard = BookmarkToggleGuard();

  // Getters — defensive copy so UI list rebuilds are not concurrent with edits.
  List<NewsArticle> get bookmarks => List<NewsArticle>.unmodifiable(_bookmarks);
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
    bool v2List = false,
  }) async {
    if (!_userService.isLoggedIn) {
      debugPrint('⚠️ User not authenticated, loading from local cache only');
      _loadBookmarksFromCache();
      return;
    }

    final generation = ++_loadGeneration;
    if (refresh || page <= 1) {
      _v2List = v2List;
    }
    final useV2 = _v2List;

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
        final BookmarkListResponse? response;
        if (useV2) {
          response = await _requireBookmarkApi.tryGetV2BookmarkList(
            page: _currentPage,
            limit: 20,
          );
          if (response == null) {
            if (generation != _loadGeneration) return;
            _failV2Refresh('Could not refresh bookmarks');
            return;
          }
        } else {
          response = await _requireBookmarkApi.getBookmarkList(
            page: _currentPage,
            limit: 20,
          );
        }

        if (generation != _loadGeneration) {
          debugPrint('🔖 Ignoring stale bookmark load (gen $generation)');
          return;
        }

        final incoming = useV2 ? response.data : _filterRemoved(response.data);
        final pageResult = useV2 && _currentPage == 1
            ? BookmarkRefreshResult.success(incoming)
            : null;

        if (_currentPage == 1) {
          _bookmarks = pageResult?.items ?? incoming;
        } else {
          _bookmarks.addAll(incoming);
        }
        if (useV2 && _currentPage == 1) {
          _removedNewsIds.clear();
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
        if (useV2) {
          debugPrint('⚠️ V2 bookmark refresh failed: $apiError');
          _failV2Refresh(apiError.toString());
          return;
        }
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
    await loadBookmarks(page: _currentPage + 1, v2List: _v2List);
  }

  /// Failed V2 refresh. Keeps [bookmarks] and records an error.
  /// Does not turn the failure into an empty list.
  void _failV2Refresh(String error) {
    final kept = BookmarkRefreshResult.failure(
      visible: _bookmarks,
      error: error,
    );
    _bookmarks = kept.items;
    _error = kept.error;
    _isLoading = false;
    notifyListeners();
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
    // Immutable replace — never mutate the list ListView may still hold.
    _bookmarks = BookmarkListEdits.remove(_bookmarks, newsId);
    final key = (article.articleId ?? article.title).trim();
    if (key.isNotEmpty) {
      _bookmarks = _bookmarks
          .where((a) => (a.articleId ?? a.title) != key)
          .toList();
    }
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

  /// V2 bookmark add/remove. Persistence is `POST` / `DELETE /api/v2/bookmarks`.
  ///
  /// `POST /api/interaction` is analytics only, and only after the bookmark
  /// write succeeds. It never decides whether the article stays bookmarked.
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

    if (!_toggleGuard.tryBegin(newsId)) {
      debugPrint('🔖 V2 bookmark already in flight for $newsId');
      return currentlyBookmarked;
    }

    final interactions = InteractionService();

    try {
      if (currentlyBookmarked) {
        NewsArticle snapshot = article;
        for (final a in _bookmarks) {
          final aId = a.newsId?.trim();
          if (aId != null && aId == newsId) {
            snapshot = a;
            break;
          }
          if ((a.articleId ?? a.title) == (article.articleId ?? article.title)) {
            snapshot = a;
            break;
          }
        }
        await _purgeLocal(article, newsId);
        notifyListeners();
        try {
          await _requireBookmarkApi.deleteV2Bookmark(newsId);
          interactions.clearBookmarkDedupe(article);
          debugPrint('[V2Bookmark] delete success');
          return false;
        } catch (e) {
          debugPrint('❌ V2 unbookmark failed — rolling back: $e');
          _removedNewsIds.remove(newsId);
          _bookmarks = BookmarkListEdits.add(_bookmarks, snapshot);
          await StorageService.addBookmark(snapshot);
          await StorageService.saveBookmarkListCache(_bookmarks);
          notifyListeners();
          rethrow;
        }
      }

      _removedNewsIds.remove(newsId);
      final bookmarkedArticle = article.copyWith(
        isBookmarked: true,
        bookmarkedAt: DateTime.now(),
        newsId: newsId,
        articleId: article.articleId ?? newsId,
      );
      _bookmarks = BookmarkListEdits.add(_bookmarks, bookmarkedArticle);
      notifyListeners();

      try {
        await _requireBookmarkApi.addV2Bookmark(newsId);
        await StorageService.addBookmark(bookmarkedArticle);
        await StorageService.saveBookmarkListCache(_bookmarks);
        try {
          await interactions.ensureBookmarkTracked(bookmarkedArticle);
        } catch (trackError) {
          debugPrint(
            '[V2Bookmark] interaction track failed after persist: $trackError',
          );
        }
        return true;
      } catch (e) {
        debugPrint('[V2Bookmark] add failed');
        await _purgeLocal(article, newsId);
        notifyListeners();
        rethrow;
      }
    } finally {
      _toggleGuard.end(newsId);
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
