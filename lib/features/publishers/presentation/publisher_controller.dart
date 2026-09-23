import 'package:flutter/foundation.dart';

import '../../../data/models/news_article.dart';
import '../../../providers/language_provider.dart';
import '../data/publisher_repository.dart';
import 'publisher_state.dart';

class PublisherController extends ChangeNotifier {
  PublisherController({
    required PublisherRepository repository,
    LanguageProvider? languageProvider,
  })  : _repo = repository,
        _language = languageProvider;

  final PublisherRepository _repo;
  final LanguageProvider? _language;

  PublisherState _state = const PublisherState();
  PublisherState get state => _state;

  bool _loadMoreInFlight = false;
  bool _refreshInFlight = false;
  String? _activeKey;
  NewsArticle? _seed;

  Future<void> open({
    required String publisherKey,
    NewsArticle? seedArticle,
  }) async {
    _activeKey = publisherKey.trim();
    _seed = seedArticle;
    if (_seed != null) _repo.cacheFromArticle(_seed!);

    _set(_state.copyWith(
      status: PublisherLoadStatus.loading,
      clearError: true,
      articles: const [],
      page: 1,
      hasMore: false,
    ));

    try {
      final publisher = await _repo.resolvePublisher(
        publisherKey: _activeKey!,
        seedArticle: _seed,
      );
      _set(_state.copyWith(publisher: publisher));

      final page = await _repo.fetchArticles(
        publisher: publisher,
        page: 1,
        limit: 20,
        language: _language?.newsLanguageCode,
      );

      _set(_state.copyWith(
        articles: page.articles,
        page: page.page,
        hasMore: page.hasMore,
        fromDedicatedEndpoint: page.fromDedicatedEndpoint,
        status: PublisherLoadStatus.ready,
        clearError: true,
      ));
    } catch (e) {
      final code = e is StateError ? e.message : 'network_error';
      _set(_state.copyWith(
        status: PublisherLoadStatus.error,
        errorCode: code,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() async {
    if (_refreshInFlight || _activeKey == null) return;
    _refreshInFlight = true;
    _set(_state.copyWith(status: PublisherLoadStatus.refreshing));
    try {
      await open(publisherKey: _activeKey!, seedArticle: _seed);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> loadMore() async {
    if (_loadMoreInFlight ||
        _refreshInFlight ||
        !_state.hasMore ||
        _state.publisher == null) {
      return;
    }
    _loadMoreInFlight = true;
    _set(_state.copyWith(status: PublisherLoadStatus.loadingMore));
    try {
      final next = _state.page + 1;
      final page = await _repo.fetchArticles(
        publisher: _state.publisher!,
        page: next,
        limit: 20,
        language: _language?.newsLanguageCode,
      );
      final merged = [..._state.articles];
      final seen = merged.map((a) => a.newsId ?? a.articleId ?? a.title).toSet();
      for (final a in page.articles) {
        final id = a.newsId ?? a.articleId ?? a.title;
        if (seen.contains(id)) continue;
        seen.add(id);
        merged.add(a);
      }
      _set(_state.copyWith(
        articles: merged,
        page: next,
        hasMore: page.hasMore,
        status: PublisherLoadStatus.ready,
      ));
    } catch (e) {
      _set(_state.copyWith(
        status: PublisherLoadStatus.ready,
        errorMessage: e.toString(),
      ));
    } finally {
      _loadMoreInFlight = false;
    }
  }

  void _set(PublisherState next) {
    _state = next;
    notifyListeners();
  }
}
