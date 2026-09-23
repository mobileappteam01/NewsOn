import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../data/recent_searches_store.dart';
import '../data/search_repository.dart';
import '../domain/search_query_validator.dart';

enum SearchStatus { idle, loading, loadingMore, ready, error }

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.recent = const [],
    this.status = SearchStatus.idle,
    this.errorCode,
    this.page = 1,
    this.hasMore = false,
  });

  final String query;
  final List<NewsArticle> results;
  final List<String> recent;
  final SearchStatus status;
  final String? errorCode;
  final int page;
  final bool hasMore;

  SearchState copyWith({
    String? query,
    List<NewsArticle>? results,
    List<String>? recent,
    SearchStatus? status,
    String? errorCode,
    bool clearError = false,
    int? page,
    bool? hasMore,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      status: status ?? this.status,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NewsSearchController extends ChangeNotifier {
  NewsSearchController({
    required SearchRepository repository,
    required String Function() newsLanguageCode,
    required SavedRegion Function() appliedRegion,
    RecentSearchesStore? recentStore,
  })  : _repo = repository,
        _newsLanguageCode = newsLanguageCode,
        _appliedRegion = appliedRegion,
        _recentStore = recentStore ?? RecentSearchesStore();

  final SearchRepository _repo;
  final String Function() _newsLanguageCode;
  final SavedRegion Function() _appliedRegion;
  final RecentSearchesStore _recentStore;

  SearchState _state = const SearchState();
  SearchState get state => _state;

  Timer? _suggestionDebounce;
  bool _loadMoreInFlight = false;
  bool _searchInFlight = false;

  /// Monotonic generation — ignore stale search responses when a newer submit wins.
  int _searchGeneration = 0;

  /// Local suggestion debounce only — does not hit the network.
  /// API search remains submit-only (Phase 5); typing does not fire `/api/v2/search`.
  static const suggestionDebounce = Duration(milliseconds: 350);

  Future<void> bootstrap() async {
    final recent = await _recentStore.load();
    _set(_state.copyWith(recent: recent));
  }

  /// Debounced local filter of recent searches (no API).
  void onQueryChanged(String raw) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(suggestionDebounce, () {
      _set(_state.copyWith(query: raw));
    });
  }

  List<String> localSuggestions(String raw) {
    final q = SearchQueryValidator.normalize(raw).toLowerCase();
    if (q.isEmpty) return _state.recent;
    return _state.recent
        .where((e) => e.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  Future<void> submit(String raw) async {
    final error = SearchQueryValidator.validate(raw);
    if (error != null) {
      _set(_state.copyWith(
        status: SearchStatus.error,
        errorCode: error,
        results: const [],
      ));
      return;
    }
    final generation = ++_searchGeneration;
    _searchInFlight = true;
    final q = SearchQueryValidator.normalize(raw);
    _set(_state.copyWith(
      query: q,
      status: SearchStatus.loading,
      clearError: true,
      page: 1,
      results: const [],
      hasMore: false,
    ));
    try {
      final response = await _repo.search(
        query: q,
        languageCode: _newsLanguageCode(),
        appliedRegion: _appliedRegion(),
        page: 1,
      );
      if (generation != _searchGeneration) return;
      final recent = await _recentStore.add(q);
      if (generation != _searchGeneration) return;
      _set(_state.copyWith(
        results: response.results,
        recent: recent,
        status: SearchStatus.ready,
        page: 1,
        hasMore: response.hasNextPage || response.results.length >= 20,
        clearError: true,
      ));
    } catch (e) {
      if (generation != _searchGeneration) return;
      _set(_state.copyWith(
        status: SearchStatus.error,
        errorCode: e is SearchException ? e.code : 'network_error',
      ));
    } finally {
      if (generation == _searchGeneration) {
        _searchInFlight = false;
      }
    }
  }

  Future<void> loadMore() async {
    if (_loadMoreInFlight ||
        _searchInFlight ||
        !_state.hasMore ||
        _state.query.isEmpty) {
      return;
    }
    final generation = _searchGeneration;
    _loadMoreInFlight = true;
    _set(_state.copyWith(status: SearchStatus.loadingMore));
    try {
      final next = _state.page + 1;
      final response = await _repo.search(
        query: _state.query,
        languageCode: _newsLanguageCode(),
        appliedRegion: _appliedRegion(),
        page: next,
      );
      if (generation != _searchGeneration) return;
      final merged = [..._state.results];
      final seen = merged.map((a) => a.newsId ?? a.articleId ?? a.title).toSet();
      for (final a in response.results) {
        final id = a.newsId ?? a.articleId ?? a.title;
        if (seen.contains(id)) continue;
        seen.add(id);
        merged.add(a);
      }
      _set(_state.copyWith(
        results: merged,
        page: next,
        hasMore: response.hasNextPage && response.results.isNotEmpty,
        status: SearchStatus.ready,
      ));
    } catch (_) {
      if (generation != _searchGeneration) return;
      _set(_state.copyWith(status: SearchStatus.ready));
    } finally {
      if (generation == _searchGeneration) {
        _loadMoreInFlight = false;
      }
    }
  }

  Future<void> clearRecent() async {
    await _recentStore.clear();
    _set(_state.copyWith(recent: const []));
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  void _set(SearchState next) {
    _state = next;
    notifyListeners();
  }
}
