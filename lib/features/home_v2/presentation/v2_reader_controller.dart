import 'package:flutter/foundation.dart';

import '../../../core/config/v2_api_config.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../../../data/services/v2_api_config_service.dart';
import '../../for_you/data/for_you_repository.dart';
import '../../news/data/v2_feed_item_mapper.dart';
import '../../news/domain/news_summary.dart';
import '../domain/home_filter_state.dart';

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
  })  : _repository = repository,
        _homeLoader = homeLoader,
        _config = configService ?? V2ApiConfigService.instance;

  static const int pageSize = 20;

  ForYouRepository? _repository;
  final V2HomePageLoader? _homeLoader;
  final V2ApiConfigService _config;
  final String Function() newsLanguageCode;
  final SavedRegion Function() appliedRegion;

  /// Committed Home filter. Used only when [homeLoader] is set.
  final HomeFilterState Function()? homeFilter;

  ForYouRepository get _forYou => _repository ??= ForYouRepository();

  V2ReaderState _state = const V2ReaderState();
  V2ReaderState get state => _state;

  final Set<String> _impressedIds = <String>{};
  bool _loadingMore = false;
  bool _refreshInFlight = false;
  int _fetchGeneration = 0;

  bool get refreshInFlight => _refreshInFlight;

  /// Counts successful fetchPage attempts for the current loadInitial cycle.
  @visibleForTesting
  int fetchAttempts = 0;

  /// True after the one allowed config-ordering retry has been used.
  bool _configRetryUsed = false;

  Future<void> loadInitial({bool keepVisible = false}) async {
    final generation = ++_fetchGeneration;
    _loadingMore = false;
    final preserveFeed =
        keepVisible && _state.articles.isNotEmpty && _state.status == V2ReaderStatus.ready;
    if (preserveFeed) {
      _state = _state.copyWith(clearError: true, page: 1);
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
          _fail(e2);
        }
      } else {
        _fail(e);
      }
    } catch (e) {
      debugPrint('⚠️ V2ReaderController load failed: $e');
      _fail(e);
    }
    notifyListeners();
  }

  Future<void> _fetchInitialPage(int generation) async {
    fetchAttempts++;
    if (_homeLoader != null) {
      await _applyHomePage(page: 1, append: false, generation: generation);
      return;
    }
    final page = await _forYou.fetchPage(
      page: 1,
      limit: pageSize,
      newsLanguageCode: newsLanguageCode(),
      appliedRegion: appliedRegion(),
      // Reader is V2-only — never paint V1 cold-start as the home feed.
      allowColdStart: false,
    );
    if (generation != _fetchGeneration) return;
    if (page.articles.isEmpty) {
      _state = _state.copyWith(
        status: V2ReaderStatus.empty,
        articles: const [],
        hasMore: false,
      );
    } else {
      _state = _state.copyWith(
        status: V2ReaderStatus.ready,
        articles: _dedupeAppend(const [], page.articles),
        hasMore: page.hasMore,
        page: page.page,
        index: 0,
      );
    }
  }

  Future<void> _applyHomePage({
    required int page,
    required bool append,
    int? keepIndex,
    required int generation,
  }) async {
    final filter = homeFilter?.call() ?? const HomeFilterState();
    final result = await _homeLoader!(
      page: page,
      limit: pageSize,
      language: newsLanguageCode(),
      filter: filter,
    );
    if (generation != _fetchGeneration) return;
    if (!append) {
      if (result.articles.isEmpty) {
        _state = _state.copyWith(
          status: V2ReaderStatus.empty,
          articles: const [],
          hasMore: false,
          page: result.page,
        );
      } else {
        _state = _state.copyWith(
          status: V2ReaderStatus.ready,
          articles: _dedupeAppend(const [], result.articles),
          hasMore: result.hasMore,
          page: result.page > 0 ? result.page : page,
          index: 0,
        );
      }
      return;
    }
    if (result.articles.isEmpty) {
      _state = _state.copyWith(hasMore: false);
      return;
    }
    final merged = _dedupeAppend(_state.articles, result.articles);
    final safeIndex = (keepIndex ?? _state.index).clamp(0, merged.length - 1);
    _state = _state.copyWith(
      articles: merged,
      hasMore: result.hasMore,
      page: page,
      index: safeIndex,
    );
  }

  void _fail(Object e) {
    // Soft refresh / resume: keep the previous feed rather than blanking UI.
    if (_state.articles.isNotEmpty) {
      _state = _state.copyWith(
        status: V2ReaderStatus.ready,
        errorMessage: e.toString(),
      );
      return;
    }
    _state = _state.copyWith(
      status: V2ReaderStatus.error,
      errorMessage: e.toString(),
    );
  }

  Future<void> refresh({bool keepVisible = true}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    notifyListeners();
    try {
      await loadInitial(keepVisible: keepVisible);
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
    notifyListeners();
    if (_state.index >= _state.articles.length - 5 && _state.hasMore) {
      unawaitedLoadMore();
    }
    return true;
  }

  bool goPrevious() {
    if (_state.index <= 0) return false;
    _state = _state.copyWith(index: _state.index - 1);
    notifyListeners();
    return true;
  }

  /// Sync visual page index from [TurnablePage] without flipping again.
  bool setIndex(int index) {
    if (index < 0 || index >= _state.articles.length) return false;
    if (index == _state.index) return true;
    _state = _state.copyWith(index: index);
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

  void unawaitedLoadMore() {
    if (_loadingMore || _refreshInFlight || !_state.hasMore) return;
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
        final page = await _forYou.fetchPage(
          page: nextPage,
          limit: pageSize,
          newsLanguageCode: newsLanguageCode(),
          appliedRegion: appliedRegion(),
          allowColdStart: false,
        );
        if (generation != _fetchGeneration) return;
        if (page.articles.isEmpty) {
          _state = _state.copyWith(hasMore: false);
        } else {
          final merged = _dedupeAppend(_state.articles, page.articles);
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
