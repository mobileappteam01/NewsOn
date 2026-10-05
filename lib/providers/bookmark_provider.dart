import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/auth_navigation_helper.dart';
import '../features/bookmarks/data/v2_bookmark_sync.dart';
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
  final NewsRepository? _repositoryOverride;
  late final NewsRepository _repository =
      _repositoryOverride ?? NewsRepository(apiKey: '');
  BookmarkApiService? _bookmarkApiService;
  final UserService _userService = UserService();

  BookmarkProvider({
    NewsRepository? repository,
    V2BookmarkRemote? v2Remote,
    V2BookmarkStore? v2Store,
    bool Function()? isLoggedIn,
    String? Function()? sessionKey,
    void Function(List<NewsArticle>)? prefetchAudio,
  })  : _repositoryOverride = repository,
        _v2RemoteOverride = v2Remote,
        _v2Store = v2Store ?? const StorageV2BookmarkStore(),
        _isLoggedInOverride = isLoggedIn,
        _sessionKeyOverride = sessionKey,
        _prefetchAudio = prefetchAudio ?? _prefetchBookmarkAudio;

  final V2BookmarkRemote? _v2RemoteOverride;
  final V2BookmarkStore _v2Store;
  final bool Function()? _isLoggedInOverride;
  final String? Function()? _sessionKeyOverride;
  final void Function(List<NewsArticle>) _prefetchAudio;

  bool get _loggedIn => _isLoggedInOverride?.call() ?? _userService.isLoggedIn;

  /// Signed-in account the V2 list belongs to.
  String get _session {
    if (_sessionKeyOverride != null) return _sessionKeyOverride() ?? '';
    return _userService.getUserId() ?? _userService.getToken() ?? '';
  }

  V2BookmarkRemote get _v2Remote => _v2RemoteOverride ?? _requireBookmarkApi;

  static void _prefetchBookmarkAudio(List<NewsArticle> bookmarks) {
    unawaited(
      NewsAudioCacheService.instance.prefetchArticles(
        bookmarks,
        maxUrls: 40,
      ),
    );
  }

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

  /// V2 page-1 list request in flight, and the session it was sent for.
  Future<void>? _v2FirstPageLoad;
  String? _v2FirstPageSession;

  /// Session whose V2 page-1 list was last applied from the server.
  String? _v2LoadedSession;

  /// Recently removed Mongo IDs — V1 list race only.
  /// A successful V2 refresh replaces the list from the API and does not
  /// consult this set.
  final Set<String> _removedNewsIds = <String>{};

  final BookmarkToggleGuard _toggleGuard = BookmarkToggleGuard();

  final V2BookmarkPendingEdits _v2Edits = V2BookmarkPendingEdits();
  Future<void> _v2WriteQueue = Future<void>.value();
  bool _v2ClearInFlight = false;
  static const int _v2ClearMaxRounds = 10;

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
    if (!_loggedIn) {
      if (v2List) {
        _showSignedOutV2();
        return;
      }
      debugPrint('⚠️ User not authenticated, loading from local cache only');
      _loadBookmarksFromCache();
      return;
    }

    final generation = ++_loadGeneration;
    if (refresh || page <= 1) {
      _v2List = v2List;
    }
    if (_v2List) {
      final session = _session;
      final load = _loadBookmarksV2(
        generation: generation,
        refresh: refresh,
        forceNetwork: forceNetwork,
        page: page,
        session: session,
      );
      if (refresh || forceNetwork || page <= 1) {
        _v2FirstPageLoad = load;
        _v2FirstPageSession = session;
      }
      try {
        await load;
      } finally {
        if (identical(_v2FirstPageLoad, load)) _v2FirstPageLoad = null;
      }
      return;
    }

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

        final incoming = _filterRemoved(response.data);

        if (_currentPage == 1) {
          _bookmarks = incoming;
        } else {
          _bookmarks.addAll(incoming);
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

  /// V2 bookmarks live on the server only. Signed out, there is nothing to
  /// show, and device copies (possibly another account's) are not read.
  void _showSignedOutV2() {
    _loadGeneration++;
    _v2List = true;
    _v2FirstPageLoad = null;
    _v2LoadedSession = null;
    _bookmarks = [];
    _removedNewsIds.clear();
    _hasMore = false;
    _totalBookmarks = 0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// `GET /api/v2/bookmarks`. A successful response replaces the list and the
  /// device copy, including an empty `items`. A failed request keeps both.
  Future<void> _loadBookmarksV2({
    required int generation,
    required bool refresh,
    required bool forceNetwork,
    required int page,
    required String session,
  }) async {
    final loadStartedAt = _v2Edits.beginLoad();
    _isLoading = true;
    _error = null;
    if (refresh || forceNetwork) {
      _currentPage = 1;
      _hasMore = true;
    } else {
      _currentPage = page;
    }
    if (_currentPage == 1 && _bookmarks.isEmpty && !forceNetwork) {
      final cached = _v2Store.readList();
      if (cached.isNotEmpty) _bookmarks = _v2Edits.applyAll(cached);
    }
    notifyListeners();

    final requestedPage = _currentPage;
    BookmarkListResponse? response;
    try {
      response = await _v2Remote.tryGetV2BookmarkList(
        page: requestedPage,
        limit: 20,
      );
    } catch (e) {
      debugPrint('⚠️ V2 bookmark refresh failed: $e');
      response = null;
    }

    if (generation != _loadGeneration) {
      debugPrint('🔖 Ignoring stale bookmark load (gen $generation)');
      return;
    }
    if (response == null) {
      _failV2Refresh('Could not refresh bookmarks');
      return;
    }

    final incoming = _v2Edits.reconcile(response.data, loadStartedAt);
    if (requestedPage == 1) {
      _bookmarks = BookmarkRefreshResult.success(incoming).items;
      _v2LoadedSession = session;
    } else {
      final seen = {for (final a in _bookmarks) v2BookmarkId(a)};
      _bookmarks = [
        ..._bookmarks,
        ...incoming.where((a) {
          final id = v2BookmarkId(a);
          return id == null || !seen.contains(id);
        }),
      ];
    }
    _removedNewsIds
      ..clear()
      ..addAll(_v2Edits.removedIds);
    _hasMore = response.pagination.hasMore;
    _totalBookmarks = response.pagination.total;
    _currentPage = response.pagination.page;
    _isLoading = false;
    debugPrint('[V2Bookmark] list applied count=${_bookmarks.length}');
    notifyListeners();

    await _writeV2Local();
    _prefetchAudio(_bookmarks);
  }

  /// Writes the current list to the device copy. Writes run one at a time and
  /// each one reads the list when it runs, so the last write always matches
  /// the latest state. Adds still waiting on the server are not written.
  Future<void> _writeV2Local() {
    final next = _v2WriteQueue.then((_) async {
      final confirmed = _bookmarks.where((a) {
        final id = v2BookmarkId(a);
        return id == null || !_v2Edits.isAddInFlight(id);
      }).toList();
      try {
        await _v2Store.writeList(confirmed);
      } catch (e) {
        debugPrint('⚠️ V2 bookmark local write failed: $e');
      }
    });
    _v2WriteQueue = next;
    return next;
  }

  /// Home-open load of the V2 list. The Bookmarks tab already refreshes page 1
  /// when it is built, so this joins that request (or skips if it already
  /// succeeded for this account) instead of sending a second
  /// `GET /api/v2/bookmarks`. Failed loads are retried; explicit refreshes
  /// keep going through [loadBookmarks].
  Future<void> ensureV2BookmarksLoaded() async {
    if (!_loggedIn) return loadBookmarks(v2List: true);
    final session = _session;
    final inFlight = _v2FirstPageLoad;
    if (inFlight != null && _v2FirstPageSession == session) await inFlight;
    if (_v2List && _v2LoadedSession == session) return;
    await loadBookmarks(v2List: true);
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

    if (!_loggedIn) {
      debugPrint('🔖 V2 bookmark requires login — opening AuthScreen');
      navigateToLoginForAccountFeatureGlobal();
      return currentlyBookmarked;
    }

    final newsId = v2BookmarkId(article);
    if (newsId == null) {
      throw Exception('Cannot bookmark: missing V2 article id');
    }

    if (!_toggleGuard.tryBegin(newsId)) {
      debugPrint('🔖 V2 bookmark already in flight for $newsId');
      return currentlyBookmarked;
    }

    final interactions = InteractionService();

    try {
      if (currentlyBookmarked) {
        final snapshot = _v2Snapshot(article, newsId);
        final edit = _v2Edits.beginRemove(newsId);
        _removedNewsIds.add(newsId);
        _bookmarks = _v2Without(_bookmarks, article, newsId);
        notifyListeners();
        await _writeV2Local();
        try {
          await _v2Remote.deleteV2Bookmark(newsId);
          _v2Edits.settle(newsId, edit);
          interactions.clearBookmarkDedupe(article);
          debugPrint('[V2Bookmark] delete success');
          return false;
        } catch (e) {
          debugPrint('❌ V2 unbookmark failed — rolling back: $e');
          _v2Edits.cancel(newsId, edit);
          _removedNewsIds.remove(newsId);
          _bookmarks = BookmarkListEdits.add(_bookmarks, snapshot);
          notifyListeners();
          await _writeV2Local();
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
      final edit = _v2Edits.beginAdd(newsId, bookmarkedArticle);
      _bookmarks = BookmarkListEdits.add(_bookmarks, bookmarkedArticle);
      notifyListeners();

      try {
        await _v2Remote.addV2Bookmark(newsId);
        _v2Edits.settle(newsId, edit);
        await _writeV2Local();
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
        _v2Edits.cancel(newsId, edit);
        _bookmarks = _v2Without(_bookmarks, article, newsId);
        notifyListeners();
        await _writeV2Local();
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

  /// Removes every V2 bookmark with `DELETE /api/v2/bookmarks/{id}` (the V2
  /// API has no bulk route), re-reading page 1 until the server list is empty.
  /// Bookmarks whose delete fails stay in the list. Returns true when none
  /// failed.
  Future<bool> clearAllBookmarksV2() async {
    if (!_loggedIn || _v2ClearInFlight) return false;
    _v2ClearInFlight = true;
    final failed = <String, NewsArticle>{};
    var leftover = <String, NewsArticle>{};
    try {
      var targets = <String, NewsArticle>{
        for (final a in _bookmarks)
          if (v2BookmarkId(a) != null) v2BookmarkId(a)!: a,
      };
      for (var round = 0; targets.isNotEmpty; round++) {
        if (round == _v2ClearMaxRounds) {
          leftover = targets;
          break;
        }
        await _deleteAllV2(targets, failed);
        BookmarkListResponse? page;
        try {
          page = await _v2Remote.tryGetV2BookmarkList(page: 1, limit: 50);
        } catch (e) {
          page = null;
        }
        if (page == null) break;
        targets = <String, NewsArticle>{
          for (final a in page.data)
            if (v2BookmarkId(a) != null && !failed.containsKey(v2BookmarkId(a)))
              v2BookmarkId(a)!: a,
        };
      }
    } finally {
      _v2ClearInFlight = false;
    }

    for (final a in [...failed.values, ...leftover.values]) {
      _bookmarks = BookmarkListEdits.add(_bookmarks, a);
    }
    _hasMore = false;
    _currentPage = 1;
    _totalBookmarks = _bookmarks.length;
    _error = failed.isEmpty
        ? null
        : 'Could not remove ${failed.length} bookmark(s)';
    notifyListeners();
    await _writeV2Local();
    return failed.isEmpty;
  }

  Future<void> _deleteAllV2(
    Map<String, NewsArticle> targets,
    Map<String, NewsArticle> failed,
  ) async {
    final claimed = <String, V2BookmarkEdit>{};
    for (final entry in targets.entries) {
      if (!_toggleGuard.tryBegin(entry.key)) continue;
      claimed[entry.key] = _v2Edits.beginRemove(entry.key);
      _removedNewsIds.add(entry.key);
      _bookmarks = _v2Without(_bookmarks, entry.value, entry.key);
    }
    notifyListeners();
    await _writeV2Local();
    for (final entry in claimed.entries) {
      final id = entry.key;
      try {
        await _v2Remote.deleteV2Bookmark(id);
        _v2Edits.settle(id, entry.value);
      } catch (e) {
        debugPrint('⚠️ V2 bookmark remove failed during clear: $e');
        _v2Edits.cancel(id, entry.value);
        _removedNewsIds.remove(id);
        failed[id] = targets[id]!;
      } finally {
        _toggleGuard.end(id);
      }
    }
  }

  NewsArticle _v2Snapshot(NewsArticle article, String newsId) {
    for (final a in _bookmarks) {
      if (v2BookmarkId(a) == newsId) return a;
      if ((a.articleId ?? a.title) == (article.articleId ?? article.title)) {
        return a;
      }
    }
    return article;
  }

  List<NewsArticle> _v2Without(
    List<NewsArticle> list,
    NewsArticle article,
    String newsId,
  ) {
    final key = (article.articleId ?? article.title).trim();
    return list.where((a) {
      if (v2BookmarkId(a) == newsId) return false;
      return key.isEmpty || (a.articleId ?? a.title) != key;
    }).toList();
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
