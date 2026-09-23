import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/search/data/search_repository.dart';
import 'package:newson/features/search/presentation/news_search_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

NewsArticle _a(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'T $id',
      link: 'https://example.com/$id',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  NewsSearchController controller(SearchFetcher fetcher) {
    return NewsSearchController(
      repository: SearchRepository(searchFetcher: fetcher),
      newsLanguageCode: () => 'en',
      appliedRegion: () => const SavedRegion(),
    );
  }

  test('short query does not call API', () async {
    var calls = 0;
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      calls++;
      return NewsResponse(status: 'ok', totalResults: 0, results: const []);
    });
    await c.submit('a');
    expect(c.state.status, SearchStatus.error);
    expect(c.state.errorCode, 'too_short');
    expect(calls, 0);
  });

  test('valid query loads results', () async {
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      expect(query, 'chennai');
      expect(page, 1);
      return NewsResponse(
        status: 'ok',
        totalResults: 1,
        results: [_a('1')],
        nextPage: '2',
      );
    });
    await c.submit('  chennai  ');
    expect(c.state.status, SearchStatus.ready);
    expect(c.state.results.map((e) => e.newsId), ['1']);
    expect(c.state.hasMore, isTrue);
    expect(c.state.recent, contains('chennai'));
  });

  test('empty result is ready with zero items', () async {
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      return NewsResponse(status: 'ok', totalResults: 0, results: const []);
    });
    await c.submit('zzzxqy');
    expect(c.state.status, SearchStatus.ready);
    expect(c.state.results, isEmpty);
  });

  test('API error surfaces error status', () async {
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      throw SearchException('network_error');
    });
    await c.submit('climate');
    expect(c.state.status, SearchStatus.error);
    expect(c.state.errorCode, 'network_error');
  });

  test('pagination loadMore appends page 2', () async {
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      if (page == 1) {
        return NewsResponse(
          status: 'ok',
          totalResults: 1,
          results: [_a('p1')],
          nextPage: '2',
        );
      }
      return NewsResponse(
        status: 'ok',
        totalResults: 1,
        results: [_a('p2')],
      );
    });
    await c.submit('news');
    await c.loadMore();
    expect(c.state.results.map((e) => e.newsId), ['p1', 'p2']);
    expect(c.state.page, 2);
  });

  test('stale slower search is ignored when a newer submit wins', () async {
    final slow = Completer<NewsResponse>();
    var calls = 0;
    final c = controller(({
      required query,
      required languageCode,
      required appliedRegion,
      required page,
      required limit,
    }) async {
      calls++;
      if (query == 'first') {
        return slow.future;
      }
      return NewsResponse(
        status: 'ok',
        totalResults: 1,
        results: [_a('second')],
      );
    });

    final first = c.submit('first');
    await Future<void>.delayed(Duration.zero);
    await c.submit('second');
    slow.complete(
      NewsResponse(
        status: 'ok',
        totalResults: 1,
        results: [_a('first')],
      ),
    );
    await first;

    expect(calls, 2);
    expect(c.state.query, 'second');
    expect(c.state.results.map((e) => e.newsId), ['second']);
    expect(c.state.status, SearchStatus.ready);
  });
}
