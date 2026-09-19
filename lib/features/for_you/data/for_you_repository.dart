import 'package:flutter/foundation.dart';

import '../../../data/models/for_you_response.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/news_response.dart';
import '../../../data/models/region_model.dart';
import '../../../data/services/backend_news_service.dart';
import '../../../core/config/v2_api_config.dart';
import 'v2_for_you_api.dart';
import '../../news/domain/news_summary.dart';

enum ForYouFeedSource { personalized, coldStartFallback, empty, anonymousFallback }

class ForYouFeedPage {
  const ForYouFeedPage({
    required this.articles,
    required this.source,
    this.hasMore = false,
    this.page = 1,
  });

  final List<NewsArticle> articles;
  final ForYouFeedSource source;
  final bool hasMore;
  final int page;
}

typedef ForYouPageFetcher = Future<ForYouResponse> Function({
  required int page,
  required int limit,
  String? language,
  SavedRegion? region,
});

typedef LatestNewsFetcher = Future<NewsResponse> Function({
  required String language,
  required int limit,
  String? country,
  String? state,
  String? district,
});

/// Consumes backend V2 For You ranking (`/api/v2/for-you`).
/// Client cold-start is only a last-resort when the V2 API fails on page 1.
/// Does not re-rank.
class ForYouRepository {
  ForYouRepository({
    ForYouPageFetcher? forYouFetcher,
    LatestNewsFetcher? todayFetcher,
    LatestNewsFetcher? breakingFetcher,
  })  : _forYouFetcher = forYouFetcher,
        _todayFetcher = todayFetcher,
        _breakingFetcher = breakingFetcher;

  ForYouPageFetcher? _forYouFetcher;
  LatestNewsFetcher? _todayFetcher;
  LatestNewsFetcher? _breakingFetcher;

  ForYouPageFetcher get _forYou =>
      _forYouFetcher ??= ({
        required page,
        required limit,
        language,
        region,
      }) =>
          V2ForYouApi().fetch(
            page: page,
            limit: limit,
            language: language,
            region: region,
          );

  LatestNewsFetcher get _today =>
      _todayFetcher ??= ({
        required language,
        required limit,
        country,
        state,
        district,
      }) =>
          BackendNewsService().fetchTodayNews(
            language: language,
            limit: limit,
            page: 1,
            country: country,
            state: state,
            district: district,
          );

  LatestNewsFetcher get _breaking =>
      _breakingFetcher ??= ({
        required language,
        required limit,
        country,
        state,
        district,
      }) =>
          BackendNewsService().fetchBreakingNews(
            language: language,
            limit: limit,
            page: 1,
            country: country,
            state: state,
            district: district,
          );

  Future<ForYouFeedPage> fetchPage({
    required int page,
    required String newsLanguageCode,
    required SavedRegion appliedRegion,
    int limit = 15,
    bool allowColdStart = true,
  }) async {
    try {
      final response = await _forYou(
        page: page,
        limit: limit,
        language: newsLanguageCode,
        region: appliedRegion,
      );
      final articles = _dedupe(response.articles);
      final mode = (response.message).trim().toLowerCase();
      final source = _sourceFromMode(mode, hasArticles: articles.isNotEmpty);

      if (articles.isNotEmpty) {
        return ForYouFeedPage(
          articles: articles,
          source: source,
          hasMore: response.pagination.hasMore,
          page: response.pagination.page,
        );
      }
      // Backend returned empty personalized/cold/anonymous page.
      if (page > 1 || !allowColdStart) {
        return ForYouFeedPage(
          articles: const [],
          source: ForYouFeedSource.empty,
          hasMore: false,
          page: page,
        );
      }
      // Page 1 empty after successful V2 call — trust backend emptiness;
      // still attempt soft local fallback only when mode suggests outage.
      if (mode == 'ok' ||
          mode == 'personalized' ||
          mode == 'cold_start' ||
          mode == 'anonymous_fallback') {
        return ForYouFeedPage(
          articles: const [],
          source: ForYouFeedSource.empty,
          hasMore: false,
          page: page,
        );
      }
    } on V2ApiConfigException {
      // Missing/disabled V2 host — never fall back to V1 news APIs.
      rethrow;
    } catch (e) {
      debugPrint('ℹ️ For You V2 fetch failed: $e');
      if (page > 1 || !allowColdStart) rethrow;
    }

    return _coldStart(
      newsLanguageCode: newsLanguageCode,
      appliedRegion: appliedRegion,
      limit: limit,
    );
  }

  ForYouFeedSource _sourceFromMode(String mode, {required bool hasArticles}) {
    switch (mode) {
      case 'personalized':
        return ForYouFeedSource.personalized;
      case 'cold_start':
        return ForYouFeedSource.coldStartFallback;
      case 'anonymous_fallback':
        return ForYouFeedSource.anonymousFallback;
      default:
        return hasArticles
            ? ForYouFeedSource.personalized
            : ForYouFeedSource.empty;
    }
  }

  Future<ForYouFeedPage> _coldStart({
    required String newsLanguageCode,
    required SavedRegion appliedRegion,
    required int limit,
  }) async {
    try {
      final today = await _today(
        language: newsLanguageCode,
        limit: limit,
        country: appliedRegion.country,
        state: appliedRegion.state,
        district: appliedRegion.district,
      );
      var articles = _dedupe(today.results);
      if (articles.isEmpty) {
        final breaking = await _breaking(
          language: newsLanguageCode,
          limit: limit,
          country: appliedRegion.country,
          state: appliedRegion.state,
          district: appliedRegion.district,
        );
        articles = _dedupe(breaking.results);
      }
      return ForYouFeedPage(
        articles: articles,
        source: articles.isEmpty
            ? ForYouFeedSource.empty
            : ForYouFeedSource.coldStartFallback,
        hasMore: false,
        page: 1,
      );
    } catch (e) {
      debugPrint('❌ For You cold-start failed: $e');
      return const ForYouFeedPage(
        articles: [],
        source: ForYouFeedSource.empty,
        hasMore: false,
        page: 1,
      );
    }
  }

  List<NewsArticle> _dedupe(List<NewsArticle> input) {
    final seen = <String>{};
    final out = <NewsArticle>[];
    for (final a in input) {
      final id = a.analyticsNewsId;
      if (seen.contains(id)) continue;
      seen.add(id);
      out.add(a);
    }
    return out;
  }
}
