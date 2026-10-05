import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/v2_api_config.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../../../data/services/v2_api_config_service.dart';
import '../../article_feedback/data/v2_article_feedback_api.dart';
import '../../article_feedback/domain/v2_article_feedback.dart';
import '../../for_you/data/for_you_repository.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../../news/domain/news_summary.dart';
import '../data/v2_home_api.dart';
import '../domain/home_filter_state.dart';
import 'v2_reader_refresh_merge.dart';

enum V2ReaderStatus { idle, loading, ready, empty, error }

/// State for the one-article-at-a-time V2 reader home.
class V2ReaderState {
  const V2ReaderState({
    this.status = V2ReaderStatus.idle,
    this.articles = const [],
    this.index = 0,
    this.hasMore = false,
    this.errorMessage,
    this.page = 1,
  });

  final V2ReaderStatus status;
  final List<NewsArticle> articles;
  final int index;
  final bool hasMore;
  final String? errorMessage;
  final int page;

  NewsArticle? get current {
    if (articles.isEmpty || index < 0 || index >= articles.length) return null;
    return articles[index];
  }

  int get total => articles.length;

  V2ReaderState copyWith({
    V2ReaderStatus? status,
    List<NewsArticle>? articles,
    int? index,
    bool? hasMore,
    String? errorMessage,
    int? page,
    bool clearError = false,
  }) {
    return V2ReaderState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      index: index ?? this.index,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      page: page ?? this.page,
    );
  }
}

/// Loads V2 feed articles via existing `/api/v2/for-you` (fixture-friendly).
typedef V2HomePageLoader = Future<V2FeedPage> Function({
  required int page,
  required int limit,
  required String language,
  required HomeFilterState filter,
});

class V2ReaderController extends ChangeNotifier {
  V2ReaderController({
    ForYouRepository? repository,
    required this.newsLanguageCode,
    required this.appliedRegion,
    V2ApiConfigService? configService,
    V2HomePageLoader? homeLoader,
    this.homeFilter,
    V2NotInterestedSender? notInterested,
    DateTime Function()? clock,
  })  : _repository = repository,
        _homeLoader = homeLoader,
        _notInterested = notInterested,
        _clock = clock ?? DateTime.now,
        _config = configService ?? V2ApiConfigService.instance;

  static const int pageSize = 20;

  ForYouRepository? _repository;
  final V2HomePageLoader? _homeLoader;
  final V2NotInterestedSender? _notInterested;
  final DateTime Function() _clock;
  final V2ApiConfigService _config;
  final String Function() newsLanguageCode;
  final SavedRegion Function() appliedRegion;

  /// Committed Home filter. Used only when [homeLoader] is set.
  final HomeFilterState Function()? homeFilter;

  ForYouRepository get _forYou => _repository ??= ForYouRepository();

  V2ReaderState _state = const V2ReaderState();
  V2ReaderState get state => _state;

  final Set<String> _impressedIds = <String>{};

  /// Articles shown on the reader page this session; refresh ranks them
  /// after unseen ones.
  final Set<String> _seenIds = <String>{};
  bool _loadingMore = false;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  bool _queuedKeepVisible = true;
  int _fetchGeneration = 0;

  bool get refreshInFlight => _refreshInFlight;

  /// Counts successful fetchPage attempts for the current loadInitial cycle.
  @visibleForTesting
  int fetchAttempts = 0;

  /// True after the one allowed config-ordering retry has been used.
  bool _configRetryUsed = false;

  /// Whether the current [loadInitial] should keep an existing feed visible.
  bool _preserveFeedThisLoad = false;

  /// Language captured at the start of the current page-1 fetch (diagnostics).
  String? _activeRequestLanguage;

  /// [feedIdentity] of the articles on screen.
  String? _displayedFeedKey;
  String? _displayedLanguage;

  /// [feedIdentity] of the latest page-1 request.
  String? _requestedFeedKey;
  int _feedSessionRevision = 0;
  int _feedMergeRevision = 0;
  int _lastRefreshNewCount = 0;

  /// The visible articles belong to another language/filter than the latest
  /// request: it is still loading, or it failed. They must not be presented
  /// as results for the new filter.
  bool get showingPreviousFeed =>
      _state.articles.isNotEmpty &&
      _displayedFeedKey != null &&
      _requestedFeedKey != null &&
      _requestedFeedKey != _displayedFeedKey;

  /// Bumped exactly once each time a page-1 result replaces the visible feed
  /// (news language, category, location, preference reload, first load) or
  /// a refresh of the same feed reopens it at the top. Home opens a new pager
  /// at the first page on every change. Failures and ignored transient empty
  /// pages keep the feed and do not bump it.
  int get feedSessionRevision => _feedSessionRevision;

  /// Bumped when a refresh of the same feed is merged around the article the
  /// reader is on (reader deeper than [V2ReaderRefreshMerge.nearTopIndex]).
  /// Home rebuilds the pager on the current article.
  int get feedMergeRevision => _feedMergeRevision;

  /// Page-1 articles the last same-feed refresh added to the feed.
  int get lastRefreshNewCount => _lastRefreshNewCount;

  /// Identity of a feed: news language plus the committed filter. Pages of
  /// different identities are never merged or kept in place of each other.
  static String feedIdentity(String language, HomeFilterState filter) =>
      '${_normLanguage(language)}|${filter.feedKey}';

  static String _normLanguage(String language) => language.trim().toLowerCase();

  HomeFilterState _currentFilter() =>
      homeFilter?.call() ?? const HomeFilterState();

  Set<String> _displayedCategoryKeys = const {};

  /// Categories the backend filtered the visible feed by (explicit or saved
  /// preferences). Empty for the default feed.
  Set<String> get displayedCategoryKeys => _displayedCategoryKeys;

  /// Articles hidden with "Not Interested" while the request is pending or
  /// after the server accepted it. Keeps in-flight pages and refreshes from
  /// showing them again this session; after a restart the server's feed is
  /// the only source.
  final Set<String> _hiddenIds = <String>{};
  final Set<String> _hidePending = <String>{};
  int _feedEditRevision = 0;
  bool _disposed = false;

  /// Bumped when an article is removed from or restored to the visible feed.
  int get feedEditRevision => _feedEditRevision;

  bool isHidePending(String articleId) =>
      _hidePending.contains(articleId.trim());

  Future<void> loadInitial({bool keepVisible = false}) async {
    final generation = ++_fetchGeneration;
    _loadingMore = false;
    _requestedFeedKey = feedIdentity(
      newsLanguageCode(),
      _homeLoader != null ? _currentFilter() : const HomeFilterState(),
    );
    final hadArticles = _state.articles.isNotEmpty;
    // Articles in the previous news language are not a usable feed for the
    // new one: drop them so neither a failure nor an empty page keeps them.
    final languageChanged = _displayedLanguage != null &&
        _normLanguage(newsLanguageCode()) != _displayedLanguage;
    // Never blank a usable feed with a full-screen loader during revalidation.
    _preserveFeedThisLoad = !languageChanged && (keepVisible || hadArticles);
    if (_preserveFeedThisLoad) {
      // Page stays with the visible articles until page 1 is applied, so a
      // failed revalidation keeps pagination where it was.
      _state = _state.copyWith(clearError: true);
    } else if (languageChanged) {
      _state = _state.copyWith(
        status: V2ReaderStatus.loading,
        articles: const [],
        hasMore: false,
        clearError: true,
        index: 0,
        page: 1,
      );
    } else {
      _state = _state.copyWith(
        status: V2ReaderStatus.loading,
        clearError: true,
        index: 0,
        page: 1,
      );
    }
    notifyListeners();
    fetchAttempts = 0;
    _configRetryUsed = false;

    try {
      await _config.ensureReady();
      await _fetchInitialPage(generation);
    } on V2ApiConfigException catch (e) {
      // Startup ordering: first attempt blocked before config usable — retry once.
      if (!_configRetryUsed) {
        _configRetryUsed = true;
        debugPrint(
          'ℹ️ V2Reader: config not ready on first attempt, retrying once: $e',
        );
        try {
          await _config.ensureReady();
          await _fetchInitialPage(generation);
        } catch (e2) {
          _fail(e2, generation: generation, kind: 'config');
        }
      } else {
        _fail(e, generation: generation, kind: 'config');
      }
    } catch (e) {
      // One limited retry for transient network/parse failures on cold start.
      if (!_preserveFeedThisLoad && fetchAttempts < 2) {
        debugPrint('ℹ️ V2Reader: transient failure, retrying once: $e');
        try {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (generation != _fetchGeneration) return;
          await _fetchInitialPage(generation);
        } catch (e2) {
          _fail(e2, generation: generation, kind: 'network');
        }
      } else {
        debugPrint('⚠️ V2ReaderController load failed: $e');
        _fail(e, generation: generation, kind: 'network');
      }
    }
    notifyListeners();
  }

  Future<void> _fetchInitialPage(int generation) async {
    fetchAttempts++;
    if (_homeLoader != null) {
      await _applyHomePage(page: 1, append: false, generation: generation);
      return;
    }
    final language = newsLanguageCode();
    _activeRequestLanguage = language;
    final started = DateTime.now();
    final page = await _forYou.fetchPage(
      page: 1,
      limit: pageSize,
      newsLanguageCode: language,
      appliedRegion: appliedRegion(),
      // Reader is V2-only — never paint V1 cold-start as the home feed.
      allowColdStart: false,
    );
    if (generation != _fetchGeneration) {
      debugPrint(
        'ℹ️ V2Reader: stale for-you gen=$generation '
        'current=$_fetchGeneration discarded',
      );
      return;
    }
    debugPrint(
      'ℹ️ V2Reader: for-you page=1 language=$language '
      'items=${page.articles.length} '
      'ms=${DateTime.now().difference(started).inMilliseconds}',
    );
    _applyPageOneResult(
      V2FeedPage(
        articles: page.articles,
        page: page.page,
        hasMore: page.hasMore,
      ),
      generation: generation,
      language: language,
      feedKey: feedIdentity(language, const HomeFilterState()),
    );
  }

  Future<void> _applyHomePage({
    required int page,
    required bool append,
    int? keepIndex,
    required int generation,
  }) async {
    final filter = _currentFilter();
    final language = newsLanguageCode();
    final feedKey = feedIdentity(language, filter);
    _activeRequestLanguage = language;
    final started = DateTime.now();
    late final V2FeedPage result;
    try {
      result = await _homeLoader!(
        page: page,
        limit: pageSize,
        language: language,
        filter: filter,
      );
    } catch (e) {
      debugPrint(
        '⚠️ V2Reader home fetch failed gen=$generation page=$page '
        'language=$language '
        'filterCats=${filter.selectedCategorySlugs.join(",")} '
        'errorType=${e.runtimeType} error=$e',
      );
      rethrow;
    }
    if (generation != _fetchGeneration) {
      debugPrint(
        'ℹ️ V2Reader: stale home gen=$generation '
        'current=$_fetchGeneration discarded',
      );
      return;
    }
    debugPrint(
      'ℹ️ V2Reader: home page=$page language=$language '
      'items=${result.articles.length} '
      'filterCats=${filter.selectedCategorySlugs.join(",")} '
      'ms=${DateTime.now().difference(started).inMilliseconds}',
    );
    if (!append) {
      _applyPageOneResult(
        result,
        generation: generation,
        language: language,
        feedKey: feedKey,
      );
      return;
    }
    if (feedKey != _displayedFeedKey) {
      debugPrint('ℹ️ V2Reader: next page for another feed discarded');
      return;
    }
    if (result.articles.isEmpty) {
      _state = _state.copyWith(hasMore: false);
      return;
    }
    final merged = _dedupeAppend(_state.articles, _withoutHidden(result.articles));
    if (merged.isEmpty) {
      _state = _state.copyWith(hasMore: result.hasMore, page: page);
      return;
    }
    final safeIndex = (keepIndex ?? _state.index).clamp(0, merged.length - 1);
    _state = _state.copyWith(
      articles: merged,
      hasMore: result.hasMore,
      page: page,
      index: safeIndex,
    );
  }

  void _applyPageOneResult(
    V2FeedPage result, {
    required int generation,
    required String language,
    required String feedKey,
  }) {
    if (generation != _fetchGeneration) return;
    // Articles from another language/category/location are not a usable feed
    // for the new one, so its page 1 always replaces them (empty included).
    final filterChanged =
        _displayedFeedKey != null && feedKey != _displayedFeedKey;
    final sameFeedRefresh = _displayedFeedKey != null &&
        !filterChanged &&
        _state.articles.isNotEmpty;
    _displayedFeedKey = feedKey;
    _displayedLanguage = _normLanguage(language);
    final visible = _withoutHidden(result.articles);
    if (visible.isEmpty) {
      // Never wipe a usable feed with a transient empty (429 window, summary
      // backlog gap) on a reload of the same filter.
      if (_state.articles.isNotEmpty && !filterChanged) {
        debugPrint(
          'ℹ️ V2Reader: empty page-1 ignored — preserving '
          '${_state.articles.length} articles '
          '(language=$_activeRequestLanguage)',
        );
        _state = _state.copyWith(
          status: V2ReaderStatus.ready,
          clearError: true,
        );
        return;
      }
      _displayedCategoryKeys = result.categoryFilters?.matchKeys ?? const {};
      _feedSessionRevision++;
      _state = _state.copyWith(
        status: V2ReaderStatus.empty,
        articles: const [],
        hasMore: false,
        index: 0,
        page: result.page,
      );
      return;
    }
    _displayedCategoryKeys = result.categoryFilters?.matchKeys ?? const {};
    if (sameFeedRefresh) {
      _applyRefreshMerge(result, visible);
      return;
    }
    _feedSessionRevision++;
    _state = _state.copyWith(
      status: V2ReaderStatus.ready,
      articles: _dedupeAppend(const [], visible),
      hasMore: result.hasMore,
      page: result.page > 0 ? result.page : 1,
      index: 0,
      clearError: true,
    );
    _noteSeen();
  }

  /// Same language and filter: reconcile page 1 with the visible feed
  /// instead of replacing it (see [V2ReaderRefreshMerge]).
  void _applyRefreshMerge(V2FeedPage result, List<NewsArticle> visible) {
    _noteSeen();
    final merged = V2ReaderRefreshMerge.merge(
      current: _state.articles,
      currentIndex: _state.index,
      currentPage: _state.page,
      currentHasMore: _state.hasMore,
      fresh: visible,
      freshPage: result.page > 0 ? result.page : 1,
      freshHasMore: result.hasMore,
      seenIds: _seenIds,
      now: _clock(),
    );
    _lastRefreshNewCount = merged.newCount;
    debugPrint(
      'ℹ️ V2Reader: refresh merged mode=${merged.mode.name} '
      'new=${merged.newCount} fromIndex=${_state.index} '
      'toIndex=${merged.index} total=${merged.articles.length} '
      'page=${merged.page} hasMore=${merged.hasMore}',
    );
    if (merged.mode == V2RefreshMergeMode.top) {
      _feedSessionRevision++;
    } else {
      _feedMergeRevision++;
    }
    _state = _state.copyWith(
      status: V2ReaderStatus.ready,
      articles: merged.articles,
      hasMore: merged.hasMore,
      page: merged.page,
      index: merged.index,
      clearError: true,
    );
    _noteSeen();
  }

  void _noteSeen() {
    final id = _state.current?.analyticsNewsId.trim();
    if (id != null && id.isNotEmpty) _seenIds.add(id);
  }

  void _fail(
    Object e, {
    required int generation,
    required String kind,
  }) {
    if (generation != _fetchGeneration) {
      debugPrint(
        'ℹ️ V2Reader: ignoring stale $kind failure gen=$generation',
      );
      return;
    }
    final statusCode = e is V2HomeException ? e.statusCode : null;
    final failureKind = e is V2HomeException ? e.kind.name : kind;
    debugPrint(
      '⚠️ V2Reader $kind failure gen=$generation '
      'language=$_activeRequestLanguage '
      'hadArticles=${_state.articles.length} '
      'httpStatus=$statusCode failureKind=$failureKind '
      'errorType=${e.runtimeType} error=$e',
    );
    // Soft refresh / revalidation / transient 429/5xx: keep the previous feed.
    if (_state.articles.isNotEmpty) {
      _state = _state.copyWith(
        status: V2ReaderStatus.ready,
        // Do not surface a sticky error banner over a valid feed for rate limits.
        clearError: e is V2HomeException && e.isTransient,
        errorMessage: e is V2HomeException && e.isTransient
            ? null
            : e.toString(),
      );
      return;
    }
    _state = _state.copyWith(
      status: V2ReaderStatus.error,
      errorMessage: e.toString(),
    );
  }

  Future<void> refresh({bool keepVisible = true}) async {
    // Always capture the latest intent. Language changes must not be dropped
    // when a resume/pull refresh is already in flight.
    if (_refreshInFlight) {
      _refreshQueued = true;
      _queuedKeepVisible = keepVisible;
      _fetchGeneration++; // discard in-flight page results
      return;
    }
    _refreshInFlight = true;
    notifyListeners();
    try {
      var keep = keepVisible;
      do {
        _refreshQueued = false;
        await loadInitial(keepVisible: keep);
        keep = _queuedKeepVisible;
      } while (_refreshQueued);
    } finally {
      _refreshInFlight = false;
      notifyListeners();
    }
  }

  bool goNext() {
    if (_state.index >= _state.articles.length - 1) {
      if (_state.hasMore) {
        unawaitedLoadMore();
      }
      return false;
    }
    _state = _state.copyWith(index: _state.index + 1);
    _noteSeen();
    notifyListeners();
    if (_state.index >= _state.articles.length - 5 && _state.hasMore) {
      unawaitedLoadMore();
    }
    return true;
  }

  bool goPrevious() {
    if (_state.index <= 0) return false;
    _state = _state.copyWith(index: _state.index - 1);
    _noteSeen();
    notifyListeners();
    return true;
  }

  /// Sync visual page index from [TurnablePage] without flipping again.
  bool setIndex(int index) {
    if (index < 0 || index >= _state.articles.length) return false;
    if (index == _state.index) return true;
    _state = _state.copyWith(index: index);
    _noteSeen();
    notifyListeners();
    if (_state.index >= _state.articles.length - 5 && _state.hasMore) {
      unawaitedLoadMore();
    }
    return true;
  }

  /// Replace the in-memory article list for local demo paging only.
  /// Does not touch the repository or analytics IDs (reuses real articles).
  void replaceArticlesForDisplay(List<NewsArticle> articles) {
    if (articles.isEmpty) return;
    final nextIndex = _state.index.clamp(0, articles.length - 1);
    _state = _state.copyWith(
      status: V2ReaderStatus.ready,
      articles: articles,
      index: nextIndex,
    );
    notifyListeners();
  }

  /// "Not Interested": removes [article] from the visible feed right away
  /// (the next article takes its place), then asks the server to exclude it.
  /// If the server does not accept it, the article is put back.
  Future<V2HideResult> hideNotInterested(NewsArticle article) async {
    final id = article.analyticsNewsId.trim();
    if (id.isEmpty) return V2HideResult.unavailable;
    if (_hiddenIds.contains(id)) return V2HideResult.duplicate;
    final position = _indexOfId(id);
    if (position < 0) return V2HideResult.unavailable;
    final feedKey = _displayedFeedKey;
    _hiddenIds.add(id);
    _hidePending.add(id);
    _removeAt(position);
    final send = _notInterested ?? V2ArticleFeedbackApi().markNotInterested;
    try {
      await send(id);
      return V2HideResult.hidden;
    } catch (e) {
      debugPrint('⚠️ V2Reader not-interested failed errorType=${e.runtimeType}');
      _hiddenIds.remove(id);
      _restore(article, position, feedKey);
      return V2HideResult.failed;
    } finally {
      _hidePending.remove(id);
    }
  }

  int _indexOfId(String id) =>
      _state.articles.indexWhere((a) => a.analyticsNewsId.trim() == id);

  List<NewsArticle> _withoutHidden(List<NewsArticle> articles) {
    if (_hiddenIds.isEmpty) return articles;
    return [
      for (final a in articles)
        if (!_hiddenIds.contains(a.analyticsNewsId.trim())) a,
    ];
  }

  void _removeAt(int position) {
    final next = List<NewsArticle>.of(_state.articles)..removeAt(position);
    _feedEditRevision++;
    if (next.isEmpty) {
      // Nothing left to show: reload page 1 rather than leave a blank page.
      _state = _state.copyWith(articles: const [], index: 0);
      notifyListeners();
      unawaited(refresh(keepVisible: false));
      return;
    }
    var index = _state.index;
    if (position < index) index--;
    index = index.clamp(0, next.length - 1);
    _state = _state.copyWith(articles: next, index: index);
    notifyListeners();
    if (index >= next.length - 5 && _state.hasMore) {
      unawaitedLoadMore();
    }
  }

  void _restore(NewsArticle article, int position, String? feedKey) {
    if (_disposed) return;
    // The feed was switched to another filter; it has its own articles.
    if (feedKey != _displayedFeedKey) return;
    if (_indexOfId(article.analyticsNewsId.trim()) >= 0) return;
    final current = _state.articles;
    final at = position.clamp(0, current.length);
    final next = List<NewsArticle>.of(current)..insert(at, article);
    var index = current.isEmpty ? 0 : _state.index;
    if (current.isNotEmpty && at < index) index++;
    _feedEditRevision++;
    _state = _state.copyWith(
      status: V2ReaderStatus.ready,
      articles: next,
      index: index.clamp(0, next.length - 1),
      clearError: true,
    );
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void unawaitedLoadMore() {
    if (_loadingMore || _refreshInFlight || !_state.hasMore) return;
    // Visible feed is still the previous language/filter (its reload failed):
    // page 2 of the new feed must not be appended to it.
    if (_displayedFeedKey != null &&
        feedIdentity(newsLanguageCode(), _currentFilter()) !=
            _displayedFeedKey) {
      return;
    }
    _loadingMore = true;
    final keepIndex = _state.index;
    final generation = _fetchGeneration;
    () async {
      try {
        await _config.ensureReady();
        if (generation != _fetchGeneration) return;
        final nextPage = _state.page + 1;
        if (_homeLoader != null) {
          await _applyHomePage(
            page: nextPage,
            append: true,
            keepIndex: keepIndex,
            generation: generation,
          );
          return;
        }
        final language = newsLanguageCode();
        final page = await _forYou.fetchPage(
          page: nextPage,
          limit: pageSize,
          newsLanguageCode: language,
          appliedRegion: appliedRegion(),
          allowColdStart: false,
        );
        if (generation != _fetchGeneration) return;
        if (feedIdentity(language, const HomeFilterState()) !=
            _displayedFeedKey) {
          return;
        }
        if (page.articles.isEmpty) {
          _state = _state.copyWith(hasMore: false);
        } else {
          final merged =
              _dedupeAppend(_state.articles, _withoutHidden(page.articles));
          if (merged.isEmpty) return;
          // Preserve visible article while pageCount grows.
          final safeIndex = keepIndex.clamp(0, merged.length - 1);
          _state = _state.copyWith(
            articles: merged,
            hasMore: page.hasMore,
            page: nextPage,
            index: safeIndex,
          );
        }
      } catch (e) {
        debugPrint('⚠️ V2ReaderController loadMore failed: $e');
      } finally {
        _loadingMore = false;
        notifyListeners();
      }
    }();
  }

  /// Append [incoming] skipping IDs already present in [existing].
  @visibleForTesting
  static List<NewsArticle> dedupeAppend(
    List<NewsArticle> existing,
    List<NewsArticle> incoming,
  ) =>
      _dedupeAppend(existing, incoming);

  static List<NewsArticle> _dedupeAppend(
    List<NewsArticle> existing,
    List<NewsArticle> incoming,
  ) {
    final seen = <String>{
      for (final a in existing)
        if (a.analyticsNewsId.trim().isNotEmpty) a.analyticsNewsId,
    };
    final out = List<NewsArticle>.of(existing);
    for (final a in incoming) {
      final id = a.analyticsNewsId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(a);
    }
    return out;
  }

  /// Returns true once for this newsId (deduped for animation rebuilds).
  bool markImpression(String newsId) {
    final id = newsId.trim();
    if (id.isEmpty) return false;
    if (_impressedIds.contains(id)) return false;
    _impressedIds.add(id);
    return true;
  }

  @visibleForTesting
  void debugSetState(V2ReaderState state) {
    _state = state;
    notifyListeners();
  }
}
