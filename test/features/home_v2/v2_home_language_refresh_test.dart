import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _a(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

/// 24-char ids prefixed with the feed language.
String _id(String language, int n) => '$language${'$n'.padLeft(22, '0')}';

List<NewsArticle> _page(String language, int page, {int count = 3}) => [
      for (var i = 0; i < count; i++) _a(_id(language, page * 100 + i)),
    ];

class _Call {
  _Call(this.page, this.language, this.filter);
  final int page;
  final String language;
  final HomeFilterState filter;
  final Completer<V2FeedPage> completer = Completer<V2FeedPage>();
}

class _Harness {
  String language = 'en';
  HomeFilterState filter = const HomeFilterState();
  final calls = <_Call>[];
  late final V2ReaderController controller = V2ReaderController(
    newsLanguageCode: () => language,
    appliedRegion: () => const SavedRegion(),
    homeFilter: () => filter,
    homeLoader: ({
      required page,
      required limit,
      required language,
      required filter,
    }) {
      final call = _Call(page, language, filter);
      calls.add(call);
      return call.completer.future;
    },
  );

  void answer(_Call call, {List<NewsArticle>? articles, bool hasMore = true}) {
    call.completer.complete(V2FeedPage(
      articles: articles ?? _page(call.language, call.page),
      page: call.page,
      hasMore: hasMore,
    ));
  }

  /// Loads page 1 in [language] and returns once it is on screen.
  Future<void> loadPageOne() async {
    final future = controller.refresh();
    await _settle();
    answer(calls.last);
    await future;
  }

  List<String> get ids =>
      controller.state.articles.map((a) => a.newsId!).toList();

  bool get allInLanguage =>
      ids.every((id) => id.startsWith(language));
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('feed identity', () {
    test('includes the news language and the filter', () {
      const f = HomeFilterState(selectedCategorySlugs: ['sports']);
      expect(
        V2ReaderController.feedIdentity('en', f),
        isNot(V2ReaderController.feedIdentity('ta', f)),
      );
      expect(
        V2ReaderController.feedIdentity('en', f),
        isNot(V2ReaderController.feedIdentity('en', const HomeFilterState())),
      );
      expect(
        V2ReaderController.feedIdentity(' EN ', f),
        V2ReaderController.feedIdentity('en', f),
      );
    });
  });

  group('Home news language change', () {
    test('en → ta requests page 1 in ta and replaces every en article',
        () async {
      final h = _Harness();
      await h.loadPageOne();
      expect(h.ids.first.startsWith('en'), isTrue);
      final revision = h.controller.feedSessionRevision;

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      // Old-language feed is invalidated immediately (not kept on screen).
      expect(h.controller.state.articles, isEmpty);
      expect(h.controller.state.status, V2ReaderStatus.loading);
      expect(h.calls.last.language, 'ta');
      expect(h.calls.last.page, 1);
      h.answer(h.calls.last);
      await future;

      expect(h.controller.state.status, V2ReaderStatus.ready);
      expect(h.allInLanguage, isTrue);
      expect(h.controller.state.index, 0);
      expect(h.controller.feedSessionRevision, revision + 1);
      expect(h.calls.length, 2);
    });

    test('ta → ml switches again with no ta article left', () async {
      final h = _Harness()..language = 'ta';
      await h.loadPageOne();
      h.controller.setIndex(2);

      h.language = 'ml';
      final future = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last);
      await future;

      expect(h.calls.map((c) => c.language), ['ta', 'ml']);
      expect(h.allInLanguage, isTrue);
      expect(h.controller.state.index, 0);
    });

    test('change during an in-flight request: old response discarded, '
        'one request per language', () async {
      final h = _Harness();
      final first = h.controller.refresh();
      await _settle();
      final enCall = h.calls.single;

      h.language = 'ta';
      await h.controller.refresh(); // queued behind the en request
      h.answer(enCall); // en answers late
      await _settle();
      expect(h.ids, isEmpty, reason: 'late en page must not be painted');

      final taCall = h.calls.last;
      expect(taCall.language, 'ta');
      h.answer(taCall);
      await first;

      expect(h.calls.map((c) => c.language), ['en', 'ta']);
      expect(h.allInLanguage, isTrue);
      expect(h.controller.refreshInFlight, isFalse);
    });

    test('keeps the category filter', () async {
      final h = _Harness()
        ..filter = const HomeFilterState(selectedCategorySlugs: ['sports']);
      await h.loadPageOne();

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      final call = h.calls.last;
      expect(call.language, 'ta');
      expect(call.filter.selectedCategorySlugs, ['sports']);
      h.answer(call);
      await future;
      expect(h.allInLanguage, isTrue);
    });

    test('keeps the location filter', () async {
      final h = _Harness()
        ..filter = const HomeFilterState(
          country: 'india',
          state: 'tamil-nadu',
          district: 'erode',
        );
      await h.loadPageOne();

      h.language = 'ml';
      final future = h.controller.refresh();
      await _settle();
      final call = h.calls.last;
      expect(call.language, 'ml');
      expect(call.filter.country, 'india');
      expect(call.filter.state, 'tamil-nadu');
      expect(call.filter.district, 'erode');
      h.answer(call);
      await future;
      expect(h.allInLanguage, isTrue);
    });

    test('stale old-language page 2 is not appended to the new feed',
        () async {
      final h = _Harness();
      await h.loadPageOne();
      h.controller.unawaitedLoadMore();
      await _settle();
      final enPage2 = h.calls.last;
      expect(enPage2.page, 2);
      expect(enPage2.language, 'en');

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      final taPage1 = h.calls.last;
      h.answer(taPage1);
      await future;
      h.answer(enPage2);
      await _settle();

      expect(h.allInLanguage, isTrue);
      expect(h.controller.state.page, 1);
    });

    test('pagination resets: next page after the switch is page 2 of ta',
        () async {
      final h = _Harness();
      await h.loadPageOne();
      h.controller.unawaitedLoadMore();
      await _settle();
      h.answer(h.calls.last);
      await _settle();
      expect(h.controller.state.page, 2);

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      expect(h.calls.last.page, 1);
      h.answer(h.calls.last);
      await future;
      expect(h.controller.state.page, 1);

      h.controller.unawaitedLoadMore();
      await _settle();
      expect(h.calls.last.page, 2);
      expect(h.calls.last.language, 'ta');
      h.answer(h.calls.last);
      await _settle();
      expect(h.controller.state.page, 2);
      expect(h.allInLanguage, isTrue);
    });

    test('empty new-language page shows empty, never the old feed', () async {
      final h = _Harness();
      await h.loadPageOne();

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last, articles: const [], hasMore: false);
      await future;

      expect(h.ids, isEmpty);
      expect(h.controller.state.status, V2ReaderStatus.empty);
    });

    test('failed new-language load does not bring the old feed back',
        () async {
      final h = _Harness();
      await h.loadPageOne();

      h.language = 'ta';
      final future = h.controller.refresh();
      await _settle();
      h.calls.last.completer.completeError(Exception('offline'));
      // One transient retry for a feed that has nothing to show.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _settle();
      h.calls.last.completer.completeError(Exception('offline'));
      await future;

      expect(h.ids, isEmpty);
      expect(h.controller.state.status, V2ReaderStatus.error);
    });

    test('same-language refresh still keeps the feed visible', () async {
      final h = _Harness();
      await h.loadPageOne();
      final before = h.ids;

      final future = h.controller.refresh();
      await _settle();
      expect(h.ids, before);
      h.answer(h.calls.last);
      await future;
      expect(h.allInLanguage, isTrue);
    });
  });
}
