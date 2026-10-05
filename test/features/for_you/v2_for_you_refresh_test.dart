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

class _Call {
  _Call(this.page, this.language, this.region);
  final int page;
  final String? language;
  final SavedRegion? region;
  final Completer<ForYouResponse> completer = Completer<ForYouResponse>();

  void answer(List<String> ids, {bool hasMore = true}) {
    completer.complete(ForYouResponse(
      message: 'personalized',
      pagination: ForYouPagination(
        total: ids.length,
        page: page,
        limit: 15,
        totalPages: hasMore ? page + 1 : page,
        hasNextPage: hasMore,
      ),
      articles: [for (final id in ids) _a(id)],
    ));
  }
}

class _Harness {
  String language = 'en';
  SavedRegion region = const SavedRegion();
  final calls = <_Call>[];

  late final ForYouController controller = ForYouController(
    repository: ForYouRepository(
      forYouFetcher: ({
        required page,
        required limit,
        language,
        region,
      }) {
        final call = _Call(page, language, region);
        calls.add(call);
        return call.completer.future;
      },
      todayFetcher: ({
        required language,
        required limit,
        country,
        state,
        district,
      }) async =>
          NewsResponse(status: 'ok', totalResults: 0, results: const []),
    ),
    newsLanguageCode: () => language,
    appliedRegion: () => region,
  );

  List<String> get ids =>
      controller.state.articles.map((a) => a.newsId!).toList();
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('For You refresh', () {
    test('makes a new page-1 request and replaces page 1 with it', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['a1', 'a2', 'a3']);
      await first;
      expect(h.ids, ['a1', 'a2', 'a3']);

      final second = h.controller.refresh();
      await _settle();
      expect(h.calls.length, 2, reason: 'refresh must hit the server again');
      expect(h.calls.last.page, 1);
      h.calls.last.answer(['b1', 'a2', 'b3']);
      await second;
      expect(h.ids, ['b1', 'a2', 'b3']);
      expect(h.controller.state.status, ForYouStatus.ready);
    });

    test('resets pagination to page 1 after pages were loaded', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['a1', 'a2']);
      await first;
      final more = h.controller.loadMore();
      await _settle();
      h.calls.last.answer(['a3', 'a4']);
      await more;
      expect(h.controller.state.page, 2);

      final refresh = h.controller.refresh();
      await _settle();
      expect(h.controller.state.page, 1);
      expect(h.calls.last.page, 1);
      h.calls.last.answer(['c1', 'c2']);
      await refresh;
      expect(h.controller.state.page, 1);
      expect(h.ids, ['c1', 'c2']);

      // Next page continues from the fresh page 1.
      final next = h.controller.loadMore();
      await _settle();
      expect(h.calls.last.page, 2);
      h.calls.last.answer(['c3']);
      await next;
      expect(h.ids, ['c1', 'c2', 'c3']);
    });

    test('an older in-flight refresh response is ignored', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      final older = h.calls.last;
      final second = h.controller.refresh();
      await _settle();
      final newer = h.calls.last;

      newer.answer(['new1', 'new2']);
      await second;
      older.answer(['old1', 'old2']);
      await first;

      expect(h.ids, ['new1', 'new2']);
    });

    test('load-more interrupted by refresh is dropped and paging still works',
        () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['a1', 'a2']);
      await first;

      final more = h.controller.loadMore();
      await _settle();
      final stalePage2 = h.calls.last;

      final refresh = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['f1', 'f2']);
      await refresh;
      stalePage2.answer(['a3', 'a4']);
      await more;
      expect(h.ids, ['f1', 'f2'], reason: 'stale page 2 must not append');

      final next = h.controller.loadMore();
      await _settle();
      expect(h.calls.last, isNot(same(stalePage2)));
      expect(h.calls.last.page, 2);
      h.calls.last.answer(['f3']);
      await next;
      expect(h.ids, ['f1', 'f2', 'f3']);
    });

    test('no duplicate articles when page 2 repeats page-1 items', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['a1', 'a2']);
      await first;
      final more = h.controller.loadMore();
      await _settle();
      h.calls.last.answer(['a2', 'a3']);
      await more;
      expect(h.ids, ['a1', 'a2', 'a3']);
    });

    test('keeps the news language and region on refresh', () async {
      final h = _Harness()
        ..language = 'ta'
        ..region = const SavedRegion(country: 'india', state: 'tamil-nadu');
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['t1']);
      await first;

      final again = h.controller.refresh();
      await _settle();
      expect(h.calls.last.language, 'ta');
      expect(h.calls.last.region?.country, 'india');
      expect(h.calls.last.region?.state, 'tamil-nadu');
      h.calls.last.answer(['t2']);
      await again;
    });

    test('language change drops the old feed and blocks stale page 2',
        () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['en1', 'en2']);
      await first;

      h.language = 'ml';
      // Language changed but refresh not yet run: no en page 2.
      await h.controller.loadMore();
      expect(h.calls.length, 1);

      final refresh = h.controller.refresh();
      await _settle();
      expect(h.ids, isEmpty, reason: 'old-language feed is invalidated');
      expect(h.calls.last.language, 'ml');
      h.calls.last.answer(['ml1']);
      await refresh;
      expect(h.ids, ['ml1']);
    });

    test('same-feed refresh keeps articles visible while loading', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      h.calls.last.answer(['a1']);
      await first;

      final again = h.controller.refresh();
      await _settle();
      expect(h.ids, ['a1']);
      expect(h.controller.state.status, ForYouStatus.loading);
      h.calls.last.answer(['b1']);
      await again;
      expect(h.ids, ['b1']);
    });

    test('dispose during an in-flight refresh does not throw', () async {
      final h = _Harness();
      final pending = h.controller.refresh();
      await _settle();
      h.controller.dispose();
      h.calls.last.answer(['a1']);
      await pending;
    });
  });
}
