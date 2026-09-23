import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/for_you_response.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';
import 'package:newson/features/for_you/presentation/for_you_controller.dart';

NewsArticle _a(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'T $id',
      link: 'https://example.com/$id',
    );

void main() {
  ForYouController controller({
    required ForYouPageFetcher forYou,
    LatestNewsFetcher? today,
  }) {
    return ForYouController(
      repository: ForYouRepository(
        forYouFetcher: forYou,
        todayFetcher: today ??
            ({
              required language,
              required limit,
              country,
              state,
              district,
            }) async =>
                NewsResponse(status: 'ok', totalResults: 0, results: const []),
      ),
      newsLanguageCode: () => 'en',
      appliedRegion: () => const SavedRegion(),
    );
  }

  test('authenticated personalized response loads articles', () async {
    final c = controller(
      forYou: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'personalized',
            pagination: ForYouPagination(
              total: 1,
              page: 1,
              limit: limit,
              totalPages: 1,
            ),
            articles: [_a('auth1')],
          ),
    );
    await c.refresh();
    expect(c.state.status, ForYouStatus.ready);
    expect(c.state.source, ForYouFeedSource.personalized);
    expect(c.state.articles.map((e) => e.newsId), ['auth1']);
  });

  test('anonymous_fallback mode is preserved', () async {
    final c = controller(
      forYou: ({
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
            ),
            articles: [_a('anon1')],
          ),
    );
    await c.refresh();
    expect(c.state.source, ForYouFeedSource.anonymousFallback);
    expect(c.state.isColdStart, isTrue);
    expect(c.state.articles, isNotEmpty);
  });

  test('empty V2 response stays empty (not client re-rank)', () async {
    var todayCalls = 0;
    final c = controller(
      forYou: ({
        required page,
        required limit,
        language,
        region,
      }) async =>
          ForYouResponse(
            message: 'anonymous_fallback',
            pagination: ForYouPagination(
              total: 0,
              page: 1,
              limit: limit,
              totalPages: 0,
            ),
            articles: const [],
          ),
      today: ({
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
    await c.refresh();
    expect(c.state.source, ForYouFeedSource.empty);
    expect(c.state.articles, isEmpty);
    expect(todayCalls, 0);
  });

  test('API failure falls back to cold-start when available', () async {
    final c = controller(
      forYou: ({
        required page,
        required limit,
        language,
        region,
      }) async {
        throw Exception('network down');
      },
      today: ({
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
    await c.refresh();
    expect(c.state.status, ForYouStatus.ready);
    expect(c.state.source, ForYouFeedSource.coldStartFallback);
    expect(c.state.articles.map((e) => e.newsId), ['cold']);
  });

  test('stale slower refresh is ignored when a newer refresh wins', () async {
    final slow = Completer<ForYouResponse>();
    var calls = 0;
    final c = controller(
      forYou: ({
        required page,
        required limit,
        language,
        region,
      }) async {
        calls++;
        if (calls == 1) return slow.future;
        return ForYouResponse(
          message: 'personalized',
          pagination: ForYouPagination(
            total: 1,
            page: 1,
            limit: limit,
            totalPages: 1,
          ),
          articles: [_a('fresh')],
        );
      },
    );

    final first = c.refresh();
    await Future<void>.delayed(Duration.zero);
    await c.refresh();
    slow.complete(
      ForYouResponse(
        message: 'personalized',
        pagination: ForYouPagination(
          total: 1,
          page: 1,
          limit: 15,
          totalPages: 1,
        ),
        articles: [_a('stale')],
      ),
    );
    await first;

    expect(calls, 2);
    expect(c.state.articles.map((e) => e.newsId), ['fresh']);
    expect(c.state.status, ForYouStatus.ready);
  });
}
