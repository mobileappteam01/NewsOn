import 'package:flutter/foundation.dart';

import '../../../core/config/v2_api_config.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../../../data/services/v2_api_config_service.dart';
import '../../for_you/data/for_you_repository.dart';

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
class V2ReaderController extends ChangeNotifier {
  V2ReaderController({
    ForYouRepository? repository,
    required this.newsLanguageCode,
    required this.appliedRegion,
    V2ApiConfigService? configService,
  })  : _repository = repository ?? ForYouRepository(),
        _config = configService ?? V2ApiConfigService.instance;

  final ForYouRepository _repository;
  final V2ApiConfigService _config;
  final String Function() newsLanguageCode;
  final SavedRegion Function() appliedRegion;

  V2ReaderState _state = const V2ReaderState();
  V2ReaderState get state => _state;

  final Set<String> _impressedIds = <String>{};
  bool _loadingMore = false;

  /// Counts successful fetchPage attempts for the current loadInitial cycle.
  @visibleForTesting
  int fetchAttempts = 0;

  /// True after the one allowed config-ordering retry has been used.
  bool _configRetryUsed = false;

  Future<void> loadInitial() async {
    _state = _state.copyWith(
      status: V2ReaderStatus.loading,
      clearError: true,
      index: 0,
      page: 1,
    );
    notifyListeners();
    fetchAttempts = 0;
    _configRetryUsed = false;

    try {
      await _config.ensureReady();
      await _fetchInitialPage();
    } on V2ApiConfigException catch (e) {
      // Startup ordering: first attempt blocked before config usable — retry once.
      if (!_configRetryUsed) {
        _configRetryUsed = true;
        debugPrint(
          'ℹ️ V2Reader: config not ready on first attempt, retrying once: $e',
        );
        try {
          await _config.ensureReady();
          await _fetchInitialPage();
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

  Future<void> _fetchInitialPage() async {
    fetchAttempts++;
    final page = await _repository.fetchPage(
      page: 1,
      limit: 20,
      newsLanguageCode: newsLanguageCode(),
      appliedRegion: appliedRegion(),
      // Reader is V2-only — never paint V1 cold-start as the home feed.
      allowColdStart: false,
    );
    if (page.articles.isEmpty) {
      _state = _state.copyWith(
        status: V2ReaderStatus.empty,
        articles: const [],
        hasMore: false,
      );
    } else {
      _state = _state.copyWith(
        status: V2ReaderStatus.ready,
        articles: page.articles,
        hasMore: page.hasMore,
        page: page.page,
        index: 0,
      );
    }
  }

  void _fail(Object e) {
    _state = _state.copyWith(
      status: V2ReaderStatus.error,
      errorMessage: e.toString(),
    );
  }

  Future<void> refresh() => loadInitial();

  bool goNext() {
    if (_state.index >= _state.articles.length - 1) {
      if (_state.hasMore) {
        unawaitedLoadMore();
      }
      return false;
    }
    _state = _state.copyWith(index: _state.index + 1);
    notifyListeners();
    if (_state.index >= _state.articles.length - 3 && _state.hasMore) {
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

  void unawaitedLoadMore() {
    if (_loadingMore || !_state.hasMore) return;
    _loadingMore = true;
    () async {
      try {
        await _config.ensureReady();
        final nextPage = _state.page + 1;
        final page = await _repository.fetchPage(
          page: nextPage,
          limit: 15,
          newsLanguageCode: newsLanguageCode(),
          appliedRegion: appliedRegion(),
          allowColdStart: false,
        );
        if (page.articles.isEmpty) {
          _state = _state.copyWith(hasMore: false);
        } else {
          final merged = [..._state.articles, ...page.articles];
          _state = _state.copyWith(
            articles: merged,
            hasMore: page.hasMore,
            page: nextPage,
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
