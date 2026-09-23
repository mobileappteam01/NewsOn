import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../../news/domain/news_summary.dart';
import '../data/for_you_repository.dart';

enum ForYouStatus { idle, loading, loadingMore, ready, error }

class ForYouState {
  const ForYouState({
    this.articles = const [],
    this.status = ForYouStatus.idle,
    this.source = ForYouFeedSource.empty,
    this.hasMore = false,
    this.page = 1,
    this.errorMessage,
  });

  final List<NewsArticle> articles;
  final ForYouStatus status;
  final ForYouFeedSource source;
  final bool hasMore;
  final int page;
  final String? errorMessage;

  bool get isColdStart =>
      source == ForYouFeedSource.coldStartFallback ||
      source == ForYouFeedSource.anonymousFallback;

  ForYouState copyWith({
    List<NewsArticle>? articles,
    ForYouStatus? status,
    ForYouFeedSource? source,
    bool? hasMore,
    int? page,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ForYouState(
      articles: articles ?? this.articles,
      status: status ?? this.status,
      source: source ?? this.source,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// V2 For You controller — consumes backend-ranked results + cold-start fallback.
/// Does not duplicate ranking on device.
class ForYouController extends ChangeNotifier {
  ForYouController({
    required ForYouRepository repository,
    required String Function() newsLanguageCode,
    required SavedRegion Function() appliedRegion,
  })  : _repo = repository,
        _newsLanguageCode = newsLanguageCode,
        _appliedRegion = appliedRegion;

  final ForYouRepository _repo;
  final String Function() _newsLanguageCode;
  final SavedRegion Function() _appliedRegion;

  ForYouState _state = const ForYouState();
  ForYouState get state => _state;

  bool _refreshInFlight = false;
  bool _loadMoreInFlight = false;

  /// Monotonic generation — ignore stale refresh responses after a newer refresh.
  int _refreshGeneration = 0;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    _refreshInFlight = true;
    _set(_state.copyWith(status: ForYouStatus.loading, clearError: true));
    try {
      final page = await _repo.fetchPage(
        page: 1,
        newsLanguageCode: _newsLanguageCode(),
        appliedRegion: _appliedRegion(),
        allowColdStart: true,
      );
      if (generation != _refreshGeneration) return;
      _set(_state.copyWith(
        articles: page.articles,
        source: page.source,
        hasMore: page.hasMore && page.source != ForYouFeedSource.empty,
        page: page.page,
        status: ForYouStatus.ready,
        clearError: true,
      ));
    } catch (e) {
      if (generation != _refreshGeneration) return;
      _set(_state.copyWith(
        status: ForYouStatus.error,
        errorMessage: e.toString(),
        articles: const [],
        source: ForYouFeedSource.empty,
        hasMore: false,
      ));
    } finally {
      if (generation == _refreshGeneration) {
        _refreshInFlight = false;
      }
    }
  }

  Future<void> loadMore() async {
    if (_loadMoreInFlight ||
        _refreshInFlight ||
        !_state.hasMore ||
        _state.source == ForYouFeedSource.empty) {
      return;
    }
    final generation = _refreshGeneration;
    _loadMoreInFlight = true;
    _set(_state.copyWith(status: ForYouStatus.loadingMore));
    try {
      final next = _state.page + 1;
      final page = await _repo.fetchPage(
        page: next,
        newsLanguageCode: _newsLanguageCode(),
        appliedRegion: _appliedRegion(),
        allowColdStart: false,
      );
      if (generation != _refreshGeneration) return;
      final merged = [..._state.articles];
      final seen = merged.map((a) => a.analyticsNewsId).toSet();
      for (final a in page.articles) {
        final id = a.analyticsNewsId;
        if (seen.contains(id)) continue;
        seen.add(id);
        merged.add(a);
      }
      _set(_state.copyWith(
        articles: merged,
        page: next,
        hasMore: page.hasMore && page.articles.isNotEmpty,
        status: ForYouStatus.ready,
      ));
    } catch (_) {
      if (generation != _refreshGeneration) return;
      _set(_state.copyWith(status: ForYouStatus.ready));
    } finally {
      if (generation == _refreshGeneration) {
        _loadMoreInFlight = false;
      }
    }
  }

  void _set(ForYouState next) {
    _state = next;
    notifyListeners();
  }
}
