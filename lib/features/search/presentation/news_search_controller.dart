import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../data/recent_searches_store.dart';
import '../data/search_repository.dart';
import '../domain/search_query_validator.dart';
import '../domain/search_session.dart';

enum SearchStatus { idle, loading, loadingMore, ready, error }

class SearchState {
  const SearchState({
    this.typedQuery = '',
    this.submittedQuery = '',
    this.searchLanguage,
    this.filters = const SearchFilters(),
    this.results = const [],
    this.recent = const [],
    this.status = SearchStatus.idle,
    this.errorCode,
    this.page = 1,
    this.hasMore = false,
  });

  /// Text in the search box; never sent until submitted.
  final String typedQuery;

  /// Query of the active search session.
  final String submittedQuery;

  /// Selected search language code; `null` means all languages.
  final String? searchLanguage;

  /// Location filters chosen inside Search (empty by default).
  final SearchFilters filters;

  final List<NewsArticle> results;
  final List<String> recent;
  final SearchStatus status;
  final String? errorCode;
  final int page;
  final bool hasMore;

  String get query => submittedQuery;

  static const Object _unset = Object();

  SearchState copyWith({
    String? typedQuery,
    String? submittedQuery,
    Object? searchLanguage = _unset,
    SearchFilters? filters,
    List<NewsArticle>? results,
    List<String>? recent,
    SearchStatus? status,
    String? errorCode,
    bool clearError = false,
    int? page,
    bool? hasMore,
  }) {
    return SearchState(
      typedQuery: typedQuery ?? this.typedQuery,
      submittedQuery: submittedQuery ?? this.submittedQuery,
      searchLanguage: identical(searchLanguage, _unset)
          ? this.searchLanguage
          : searchLanguage as String?,
      filters: filters ?? this.filters,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      status: status ?? this.status,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// V2 search state. Independent of the Home language and Home region: only
/// the search language and filters chosen here are sent.
class NewsSearchController extends ChangeNotifier {
  NewsSearchController({
    required SearchRepository repository,
    RecentSearchesStore? recentStore,
  })  : _repo = repository,
        _recentStore = recentStore ?? RecentSearchesStore();

  final SearchRepository _repo;
  final RecentSearchesStore _recentStore;

  SearchState _state = const SearchState();
  SearchState get state => _state;

  Timer? _suggestionDebounce;
  bool _loadMoreInFlight = false;
  bool _searchInFlight = false;

  /// Values of the active search; [loadMore] pages with these only.
  SearchSession? _session;

  /// Monotonic generation — ignore stale search responses when a newer submit wins.
  int _searchGeneration = 0;

  /// Bumped per recent-history change; only the latest one's stored list is
  /// applied, so an earlier write never restores a removed term.
  int _recentRevision = 0;

  /// Local suggestion debounce only — does not hit the network.
  /// API search remains submit-only (Phase 5); typing does not fire `/api/v2/search`.
  static const suggestionDebounce = Duration(milliseconds: 350);

  Future<void> bootstrap() async {
    final revision = _recentRevision;
    final recent = await _recentStore.load();
    if (revision != _recentRevision) return;
    _set(_state.copyWith(recent: recent));
  }

  /// Debounced local filter of recent searches (no API, no persistence).
  /// Recent searches are written only from [submit].
  void onQueryChanged(String raw) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(suggestionDebounce, () {
      _set(_state.copyWith(typedQuery: raw));
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

  /// Selects the search language (`null` = all languages) and re-runs the
  /// active search with it.
  Future<void> setSearchLanguage(String? code) async {
    final language = SearchLanguages.normalize(code);
    if (language == _state.searchLanguage) return;
    _set(_state.copyWith(searchLanguage: language));
    await _rerunActiveSearch();
  }

  /// Applies explicit Search location filters and re-runs the active search.
  Future<void> setSearchFilters(SearchFilters filters) async {
    if (filters == _state.filters) return;
    _set(_state.copyWith(filters: filters));
    await _rerunActiveSearch();
  }

  Future<void> _rerunActiveSearch() async {
    final query = _session?.query;
    if (query == null) return;
    await submit(query);
  }

  Future<void> submit(String raw) async {
    final error = SearchQueryValidator.validate(raw);
    if (error != null) {
      _startNewSession(null);
      _set(
        _state.copyWith(
          typedQuery: raw,
          submittedQuery: '',
          status: SearchStatus.error,
          errorCode: error,
          results: const [],
          page: 1,
          hasMore: false,
        ),
      );
      return;
    }
    final session = SearchSession(
      query: SearchQueryValidator.normalize(raw),
      language: _state.searchLanguage,
      filters: _state.filters,
    );
    final generation = _startNewSession(session);
    _searchInFlight = true;
    _set(
      _state.copyWith(
        typedQuery: raw,
        submittedQuery: session.query,
        status: SearchStatus.loading,
        clearError: true,
        page: 1,
        results: const [],
        hasMore: false,
      ),
    );
    try {
      final response = await _repo.search(
        query: session.query,
        language: session.language,
        filters: session.filters,
        page: 1,
      );
      if (generation != _searchGeneration) return;
      final recentRevision = ++_recentRevision;
      final recent = await _recentStore.add(session.query);
      if (generation != _searchGeneration) return;
      _set(
        _state.copyWith(
          results: response.results,
          recent: recentRevision == _recentRevision ? recent : null,
          status: SearchStatus.ready,
          page: 1,
          hasMore: response.hasNextPage,
          clearError: true,
        ),
      );
    } catch (e) {
      if (generation != _searchGeneration) return;
      _set(
        _state.copyWith(
          status: SearchStatus.error,
          errorCode: e is SearchException ? e.code : 'network_error',
        ),
      );
    } finally {
      if (generation == _searchGeneration) {
        _searchInFlight = false;
      }
    }
  }

  Future<void> loadMore() async {
    final session = _session;
    if (session == null ||
        _loadMoreInFlight ||
        _searchInFlight ||
        !_state.hasMore) {
      return;
    }
    final generation = _searchGeneration;
    _loadMoreInFlight = true;
    final next = _state.page + 1;
    _set(_state.copyWith(status: SearchStatus.loadingMore));
    try {
      final response = await _repo.search(
        query: session.query,
        language: session.language,
        filters: session.filters,
        page: next,
      );
      if (generation != _searchGeneration) return;
      final merged = [..._state.results];
      final seen =
          merged.map((a) => a.newsId ?? a.articleId ?? a.title).toSet();
      for (final a in response.results) {
        final id = a.newsId ?? a.articleId ?? a.title;
        if (seen.contains(id)) continue;
        seen.add(id);
        merged.add(a);
      }
      _set(
        _state.copyWith(
          results: merged,
          page: next,
          hasMore: response.hasNextPage,
          status: SearchStatus.ready,
        ),
      );
    } catch (_) {
      if (generation != _searchGeneration) return;
      _set(_state.copyWith(status: SearchStatus.ready));
    } finally {
      if (generation == _searchGeneration) {
        _loadMoreInFlight = false;
      }
    }
  }

  /// Resets the query, language, filters, results and pagination. Recent
  /// history is kept.
  void clear() {
    _suggestionDebounce?.cancel();
    _startNewSession(null);
    _set(SearchState(recent: _state.recent));
  }

  /// Invalidates every in-flight request; their late responses and `finally`
  /// blocks see a stale generation and leave the new session alone.
  int _startNewSession(SearchSession? session) {
    _session = session;
    _searchInFlight = false;
    _loadMoreInFlight = false;
    return ++_searchGeneration;
  }

  Future<void> clearRecent() async {
    _recentRevision++;
    _set(_state.copyWith(recent: const []));
    await _recentStore.clear();
  }

  /// Removes one recent search term; the rest of the history is kept.
  Future<void> removeRecent(String term) async {
    if (!_state.recent.contains(term)) return;
    final revision = ++_recentRevision;
    _set(
      _state.copyWith(
        recent: [
          for (final e in _state.recent)
            if (e != term) e,
        ],
      ),
    );
    final persisted = await _recentStore.remove(term);
    if (revision != _recentRevision) return;
    _set(_state.copyWith(recent: persisted));
  }

  @override
  void dispose() {
    _disposed = true;
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  bool _disposed = false;

  void _set(SearchState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
