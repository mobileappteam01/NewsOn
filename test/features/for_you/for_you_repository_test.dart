import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/for_you_response.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';

NewsArticle _a(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'T $id',
      link: 'https://example.com/$id',
    );

void main() {
  const region = SavedRegion();

  test('personalized results skip cold start', () async {
    var todayCalls = 0;
    final repo = ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'personalized',
            pagination: ForYouPagination(
              total: 2,
              page: 1,
              limit: limit,
              totalPages: 1,
              hasNextPage: false,
            ),
            articles: [_a('1'), _a('1'), _a('2')], // duplicate id
          ),
      todayFetcher: ({
        required language,
        required limit,
        country,
        state,
        district,
      }) async {
        todayCalls++;
        return NewsResponse(status: 'ok', totalResults: 0, results: const []);
      },
    );

    final page = await repo.fetchPage(
      page: 1,
      newsLanguageCode: 'en',
      appliedRegion: region,
    );
    expect(page.source, ForYouFeedSource.personalized);
    expect(page.articles.map((e) => e.newsId), ['1', '2']);
    expect(todayCalls, 0);
  });

  test('empty V2 personalized page trusts backend (no client re-rank)', () async {
    var todayCalls = 0;
    final repo = ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'personalized',
            pagination: ForYouPagination(
              total: 0,
              page: 1,
              limit: limit,
              totalPages: 0,
            ),
            articles: const [],
          ),
      todayFetcher: ({
        required language,
        required limit,
        country,
        state,
        district,
      }) async {
        todayCalls++;
        return NewsResponse(
          status: 'ok',
          totalResults: 1,
          results: [_a('cold')],
        );
      },
    );

    final page = await repo.fetchPage(
      page: 1,
      newsLanguageCode: 'ta',
      appliedRegion: region,
    );
    expect(page.source, ForYouFeedSource.empty);
    expect(page.articles, isEmpty);
    expect(todayCalls, 0);
  });

  test('API failure on page 1 uses cold-start fallback', () async {
    final repo = ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) async {
        throw Exception('network');
      },
      todayFetcher: ({
        required language,
        required limit,
        country,
        state,
        district,
      }) async =>
          NewsResponse(
            status: 'ok',
            totalResults: 1,
            results: [_a('cold')],
          ),
    );

    final page = await repo.fetchPage(
      page: 1,
      newsLanguageCode: 'ta',
      appliedRegion: region,
    );
    expect(page.source, ForYouFeedSource.coldStartFallback);
    expect(page.articles.single.newsId, 'cold');
    expect(page.hasMore, isFalse);
  });

  test('anonymous_fallback mode maps correctly', () async {
    final repo = ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'anonymous_fallback',
            pagination: ForYouPagination(
              total: 1,
              page: 1,
              limit: limit,
              totalPages: 1,
              hasNextPage: false,
            ),
            articles: [_a('a1')],
          ),
    );

    final page = await repo.fetchPage(
      page: 1,
      newsLanguageCode: 'en',
      appliedRegion: region,
    );
    expect(page.source, ForYouFeedSource.anonymousFallback);
    expect(page.articles.single.newsId, 'a1');
  });

  test('cold start disabled yields empty when personalized empty', () async {
    final repo = ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'ok',
            pagination: ForYouPagination(
              total: 0,
              page: 2,
              limit: limit,
              totalPages: 0,
            ),
            articles: const [],
          ),
    );

    final page = await repo.fetchPage(
      page: 2,
      newsLanguageCode: 'en',
      appliedRegion: region,
      allowColdStart: false,
    );
    expect(page.source, ForYouFeedSource.empty);
    expect(page.articles, isEmpty);
  });
}
