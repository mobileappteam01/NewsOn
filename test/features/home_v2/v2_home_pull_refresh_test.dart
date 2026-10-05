import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_home.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_refresh_merge.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_page.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_page_turn.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:turnable_page/turnable_page.dart';

final _now = DateTime.utc(2026, 9, 30, 12);

NewsArticle _art(
  String id, {
  int? minutesAgo,
  String publisher = 'pub',
  String title = '',
  String? summary,
}) => NewsArticle(
  articleId: id,
  newsId: id,
  title: title.isEmpty ? 'Title $id' : title,
  sourceName: publisher,
  sourceId: publisher,
  category: const ['World'],
  pubDate: minutesAgo == null
      ? null
      : _now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
  v2Summary: summary,
  summaryStatus: summary == null ? 'unavailable' : 'completed',
);

List<NewsArticle> _series(String tag, int count, {int from = 0}) => [
  for (var i = from; i < from + count; i++) _art('$tag-$i'),
];

List<String> _ids(List<NewsArticle> list) => [for (final a in list) a.newsId!];

V2ApiConfigService _readyConfig() {
  const config = V2ApiConfig(
    baseUrl: 'https://v2-api.newson.app',
    enabled: true,
  );
  return V2ApiConfigService(
    fetcher: () async => config,
    cacheReader: () => null,
    cacheWriter: (_) async {},
  )..debugSetConfig(config);
}

class _Call {
  _Call(this.page, this.language);
  final int page;
  final String language;
  final Completer<V2FeedPage> completer = Completer<V2FeedPage>();
}

class _Harness {
  _Harness({this.language = 'en'});

  String language;
  final calls = <_Call>[];
  late final V2ReaderController controller = V2ReaderController(
    configService: _readyConfig(),
    newsLanguageCode: () => language,
    appliedRegion: () => const SavedRegion(),
    homeFilter: () => const HomeFilterState(),
    notInterested: (_) async {},
    clock: () => _now,
    homeLoader:
        ({required page, required limit, required language, required filter}) {
          final call = _Call(page, language);
          calls.add(call);
          return call.completer.future;
        },
  );

  V2ReaderState get state => controller.state;
  List<String> get ids => _ids(state.articles);

  Future<void> refreshWith(
    List<NewsArticle> articles, {
    bool hasMore = false,
  }) async {
    final future = controller.refresh();
    await _settle();
    final call = calls.last;
    call.completer.complete(
      V2FeedPage(articles: articles, page: call.page, hasMore: hasMore),
    );
    await future;
  }

  Future<void> answerLoadMore(
    List<NewsArticle> articles, {
    bool hasMore = false,
  }) async {
    final call = calls.last;
    call.completer.complete(
      V2FeedPage(articles: articles, page: call.page, hasMore: hasMore),
    );
    await _settle();
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('freshness ranking', () {
    test('windows 0–15, 15–30, 30–60, 60–120 minutes; older has none', () {
      int? w(int? minutes) => V2ReaderRefreshMerge.freshnessWindow(
        _art('x', minutesAgo: minutes),
        _now,
      );
      expect(w(0), 0);
      expect(w(14), 0);
      expect(w(15), 1);
      expect(w(29), 1);
      expect(w(30), 2);
      expect(w(59), 2);
      expect(w(60), 3);
      expect(w(120), 3);
      expect(w(121), isNull);
      expect(w(null), isNull);
      expect(w(-5), 0, reason: 'clock skew counts as newest');
    });

    test('unseen fresh first, then older unseen, then seen; window order is '
        'never broken', () {
      final page = [
        _art('a', minutesAgo: 5),
        _art('b', minutesAgo: 20),
        _art('c', minutesAgo: 40),
        _art('d', minutesAgo: 90),
        _art('e', minutesAgo: 300),
        _art('f', minutesAgo: 400),
      ];
      final ranked = V2ReaderRefreshMerge.rank(
        page,
        seenIds: {'a', 'c'},
        knownIds: {'a', 'b', 'c', 'd', 'e', 'f'},
        now: _now,
      );
      expect(_ids(ranked), ['b', 'd', 'e', 'f', 'a', 'c']);
    });

    test(
      'inside a window, articles new to the feed come before loaded ones',
      () {
        final page = [
          _art('loaded', minutesAgo: 3),
          _art('new', minutesAgo: 8),
        ];
        final ranked = V2ReaderRefreshMerge.rank(
          page,
          seenIds: const {},
          knownIds: {'loaded'},
          now: _now,
        );
        expect(_ids(ranked), ['new', 'loaded']);
      },
    );

    test('publishers alternate inside a window without leaving it', () {
      final page = [
        _art('x1', minutesAgo: 1, publisher: 'X'),
        _art('x2', minutesAgo: 2, publisher: 'X'),
        _art('x3', minutesAgo: 3, publisher: 'X'),
        _art('y1', minutesAgo: 4, publisher: 'Y'),
        _art('z1', minutesAgo: 5, publisher: 'Z'),
        _art('old', minutesAgo: 20, publisher: 'X'),
      ];
      final ranked = V2ReaderRefreshMerge.rank(
        page,
        seenIds: const {},
        knownIds: const {},
        now: _now,
      );
      expect(_ids(ranked), ['x1', 'y1', 'x2', 'z1', 'x3', 'old']);
    });

    test('ranking ignores the language of the articles', () {
      List<String> rankFor(String lang) => _ids(
        V2ReaderRefreshMerge.rank(
          [
            _art('$lang-1', minutesAgo: 2, publisher: 'P'),
            _art('$lang-2', minutesAgo: 3, publisher: 'P'),
            _art('$lang-3', minutesAgo: 25, publisher: 'Q'),
            _art('$lang-4', minutesAgo: 200, publisher: 'Q'),
          ],
          seenIds: {'$lang-1'},
          knownIds: const {},
          now: _now,
        ),
      ).map((id) => id.split('-').last).toList();
      expect(rankFor('ta'), rankFor('en'));
    });
  });

  group('merge', () {
    test('overlap keeps older loaded pages after page 1 and their page', () {
      final current = _series('p', 40); // pages 1–2 loaded
      final fresh = [_art('n1'), _art('n2'), ..._series('p', 18)];
      final merged = V2ReaderRefreshMerge.merge(
        current: current,
        currentIndex: 0,
        currentPage: 2,
        currentHasMore: true,
        fresh: fresh,
        freshPage: 1,
        freshHasMore: true,
        seenIds: {'p-0'},
        now: _now,
      );
      expect(merged.mode, V2RefreshMergeMode.top);
      expect(merged.newCount, 2);
      expect(merged.page, 2);
      expect(merged.hasMore, isTrue);
      expect(merged.articles.length, 42);
      expect(_ids(merged.articles).toSet().length, 42);
      expect(_ids(merged.articles).take(3), ['n1', 'n2', 'p-1']);
      // p-0 was seen: after every unseen page-1 article, before page 1's
      // continuation.
      expect(_ids(merged.articles)[19], 'p-0');
      expect(_ids(merged.articles).skip(20).first, 'p-18');
    });

    test('no overlap: nothing from the old tail is kept (no gap)', () {
      final merged = V2ReaderRefreshMerge.merge(
        current: _series('old', 40),
        currentIndex: 1,
        currentPage: 2,
        currentHasMore: true,
        fresh: _series('new', 20),
        freshPage: 1,
        freshHasMore: true,
        seenIds: const {},
        now: _now,
      );
      expect(_ids(merged.articles), _ids(_series('new', 20)));
      expect(merged.page, 1);
      expect(merged.hasMore, isTrue);
    });

    test('deep position: history kept, fresh unseen next, no duplicates', () {
      final current = _series('p', 20);
      final fresh = [_art('n1'), ..._series('p', 19)];
      final merged = V2ReaderRefreshMerge.merge(
        current: current,
        currentIndex: 8,
        currentPage: 1,
        currentHasMore: true,
        fresh: fresh,
        freshPage: 1,
        freshHasMore: true,
        seenIds: {for (var i = 0; i <= 8; i++) 'p-$i'},
        now: _now,
      );
      expect(merged.mode, V2RefreshMergeMode.inPlace);
      expect(merged.index, 8);
      final ids = _ids(merged.articles);
      expect(ids.take(9), _ids(_series('p', 9)));
      expect(ids[9], 'n1');
      expect(ids.skip(10).take(10), _ids(_series('p', 10, from: 9)));
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 21);
    });

    test('duplicate ids inside page 1 are collapsed', () {
      final merged = V2ReaderRefreshMerge.merge(
        current: _series('p', 3),
        currentIndex: 0,
        currentPage: 1,
        currentHasMore: false,
        fresh: [_art('p-0'), _art('p-0'), _art('p-1'), _art('p-2')],
        freshPage: 1,
        freshHasMore: false,
        seenIds: const {},
        now: _now,
      );
      expect(_ids(merged.articles), ['p-0', 'p-1', 'p-2']);
    });
  });

  group('controller refresh', () {
    test(
      'refresh fetches page 1 and puts genuinely new articles first',
      () async {
        final h = _Harness();
        await h.refreshWith([
          for (var i = 0; i < 20; i++) _art('a-$i', minutesAgo: 30 + i),
        ], hasMore: true);
        final callsBefore = h.calls.length;

        await h.refreshWith([
          _art('n-0', minutesAgo: 2),
          _art('n-1', minutesAgo: 6),
          for (var i = 0; i < 18; i++) _art('a-$i', minutesAgo: 30 + i),
        ], hasMore: true);
        expect(h.calls.length, callsBefore + 1);
        expect(h.calls.last.page, 1);
        expect(h.ids.take(2), ['n-0', 'n-1']);
        expect(h.controller.lastRefreshNewCount, 2);
        expect(h.state.index, 0);
        expect(h.ids.length, 22, reason: 'a-18, a-19 are kept, not dropped');
      },
    );

    test(
      'no new data: the article already shown does not stay first',
      () async {
        final h = _Harness();
        final page = [
          for (var i = 0; i < 6; i++) _art('a-$i', minutesAgo: 10 + i * 10),
        ];
        await h.refreshWith(page);
        final firsts = <String>[h.ids.first];
        for (var n = 0; n < 4; n++) {
          await h.refreshWith(page);
          firsts.add(h.ids.first);
          expect(h.ids.toSet(), page.map((a) => a.newsId).toSet());
        }
        expect(firsts, ['a-0', 'a-1', 'a-2', 'a-3', 'a-4']);
      },
    );

    test('refresh with page 2 loaded keeps pagination on page 3', () async {
      final h = _Harness();
      await h.refreshWith(_series('p', 20), hasMore: true);
      h.controller.setIndex(16);
      await _settle();
      expect(h.calls.last.page, 2);
      await h.answerLoadMore(_series('p', 20, from: 20), hasMore: true);
      expect(h.state.page, 2);
      h.controller.setIndex(10);

      await h.refreshWith([_art('n-0'), ..._series('p', 19)], hasMore: true);
      expect(h.state.page, 2);
      expect(h.state.index, 10);
      expect(h.state.current?.newsId, 'p-10');
      expect(h.ids.length, 41);
      expect(h.ids.toSet().length, 41);

      h.controller.setIndex(h.ids.length - 2);
      await _settle();
      expect(h.calls.last.page, 3);
      await h.answerLoadMore(_series('p', 20, from: 39), hasMore: false);
      expect(h.ids.length, 60);
      expect(h.ids.toSet().length, 60, reason: 'shifted page 3 is deduped');
      expect(h.state.hasMore, isFalse);
    });

    test('five refreshes: no stuck state, duplicates or disappearing '
        'articles, position kept', () async {
      final h = _Harness(language: 'ta');
      await h.refreshWith(_series('p', 20), hasMore: true);
      h.controller.setIndex(7);
      final everShown = <String>{...h.ids};
      for (var n = 0; n < 5; n++) {
        final shownId = h.state.current!.newsId;
        await h.refreshWith([
          _art('n$n'),
          ...h.state.articles.take(19),
        ], hasMore: true);
        expect(h.controller.refreshInFlight, isFalse);
        expect(h.state.status, V2ReaderStatus.ready);
        expect(h.ids.toSet().length, h.ids.length);
        expect(h.state.current?.newsId, shownId);
        expect(h.ids.toSet().containsAll(everShown), isTrue);
        everShown.addAll(h.ids);
      }
      expect(h.ids.length, 25);
    });

    test('ta → en → ta → en: each switch replaces the feed at article 1; '
        'same-language refresh merges', () async {
      final h = _Harness(language: 'ta');
      await h.refreshWith(_series('ta', 10));
      for (final lang in ['en', 'ta', 'en']) {
        h.controller.setIndex(6);
        h.language = lang;
        await h.refreshWith(_series(lang, 10));
        expect(h.ids, _ids(_series(lang, 10)));
        expect(h.state.index, 0);
        expect(h.state.page, 1);

        h.controller.setIndex(6);
        final merges = h.controller.feedMergeRevision;
        await h.refreshWith([_art('$lang-new'), ..._series(lang, 9)]);
        expect(h.controller.feedMergeRevision, merges + 1);
        expect(h.state.current?.newsId, '$lang-6');
        expect(h.ids[7], '$lang-new');
        expect(h.ids.every((id) => id.startsWith('$lang-')), isTrue);
      }
    });
  });

  group('pull gesture (Home body wiring, real TurnablePage)', () {
    final shortEn = _art(
      'en-short',
      title: 'Short headline',
      summary: 'A short summary that fits on the page.',
    );
    final shortTa = _art(
      'ta-short',
      title: 'சுருக்கமான தலைப்பு',
      summary: 'பக்கத்தில் பொருந்தும் சிறிய சுருக்கம்.',
    );
    final longEn = _art(
      'en-long',
      title: 'A long headline ' * 6,
      summary: 'A long summary sentence that keeps going. ' * 40,
    );
    final longTa = _art(
      'ta-long',
      title: 'மிக நீண்ட தலைப்பு செய்தி ' * 6,
      summary:
          'இந்த செய்தி சுருக்கம் மிகவும் நீளமானது மற்றும் தொடர்கிறது. ' * 40,
    );

    Future<void> setPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<int> pulls(
      WidgetTester tester,
      List<NewsArticle> pages, {
      required List<Offset Function(Rect page)> starts,
      bool legacy = false,
    }) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _PullHarness(
          articles: pages,
          legacy: legacy,
          onRefresh: () async => refreshes++,
        ),
      );
      await tester.pump();
      final page = tester.getRect(find.byType(TurnablePage));
      for (final start in starts) {
        await tester.timedDragFrom(
          start(page),
          const Offset(0, 320),
          const Duration(milliseconds: 450),
        );
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      return refreshes;
    }

    Offset center(Rect p) => Offset(p.center.dx, p.top + p.height * 0.35);
    Offset upperLeft(Rect p) => Offset(p.left + 70, p.top + 70);
    Offset nearTopRight(Rect p) => Offset(p.right - 60, p.top + 60);
    Offset lower(Rect p) => Offset(p.center.dx + 40, p.top + p.height * 0.7);
    final tenPulls = [
      for (var i = 0; i < 10; i++)
        [center, upperLeft, nearTopRight, lower, center][i % 5],
    ];

    for (final (name, article, overflows) in [
      ('English, fits', shortEn, false),
      ('Tamil, fits', shortTa, false),
      ('English, overflows', longEn, true),
      ('Tamil, overflows', longTa, true),
    ]) {
      testWidgets('$name: 10 of 10 pulls refresh', (tester) async {
        await setPhone(tester);
        final count = await pulls(tester, [
          article,
          _art('next-1'),
          _art('next-2'),
        ], starts: tenPulls);
        expect(count, 10);

        final articleScroll = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(V2ArticlePage).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        expect(articleScroll.maxScrollExtent > 0, overflows);

        // The near-top-right start was inside the previous corner zone
        // (0.12 of the diagonal) and is outside the current one.
        final page = tester.getRect(find.byType(TurnablePage));
        final diagonal = Offset(page.width, page.height).distance;
        expect(60 < diagonal * 0.12, isTrue);
        expect(60 > diagonal * V2PageTurn.cornerTriggerAreaSize, isTrue);
      });
    }

    testWidgets('previous wiring missed pulls on overflowing articles '
        '(root cause regression guard)', (tester) async {
      await setPhone(tester);
      final count = await pulls(
        tester,
        [longTa, _art('next-1')],
        starts: [center, lower],
        legacy: true,
      );
      expect(count, 0);
    });

    for (final (corner, expected) in [
      (0.12, 0),
      (V2PageTurn.cornerTriggerAreaSize, 1),
    ]) {
      testWidgets('pull starting near the top-right corner with corner zone '
          '$corner refreshes $expected time(s)', (tester) async {
        await setPhone(tester);
        var refreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RefreshIndicator(
                onRefresh: () async => refreshes++,
                notificationPredicate: v2ReaderPullNotificationPredicate,
                child: LayoutBuilder(
                  builder: (_, c) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    child: SizedBox(
                      height: c.maxHeight,
                      width: c.maxWidth,
                      child: TurnablePage(
                        controller: PageFlipController(),
                        pageCount: 3,
                        pageViewMode: PageViewMode.single,
                        textDirection: TextDirection.ltr,
                        aspectRatio: c.maxWidth / c.maxHeight,
                        settings: FlipSettings(
                          startPageIndex: 0,
                          swipeDistance: 70,
                          cornerTriggerAreaSize: corner,
                          mobileScrollSupport: true,
                          swipeAngleThreshold: 1.45,
                        ),
                        builder: (context, i, _) => V2ArticlePage(
                          article: [shortTa, shortEn, longEn][i],
                          cutsLabel: 'NewsOn Cut',
                          index: i,
                          total: 3,
                          bookmarked: false,
                          onBookmark: () {},
                          onShare: () {},
                          onViewFullArticle: () {},
                          onPrevious: () {},
                          onNext: () {},
                          showAdSlot: false,
                          showHeroActions: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final page = tester.getRect(find.byType(TurnablePage));
        await tester.timedDragFrom(
          nearTopRight(page),
          const Offset(0, 320),
          const Duration(milliseconds: 450),
        );
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(refreshes, expected);
      });
    }

    testWidgets('scrolled-down article: pulling back up does not refresh; '
        'the next pull from the top does', (tester) async {
      await setPhone(tester);
      var refreshes = 0;
      await tester.pumpWidget(
        _PullHarness(
          articles: [longEn, _art('next-1')],
          onRefresh: () async => refreshes++,
        ),
      );
      await tester.pump();
      final page = tester.getRect(find.byType(TurnablePage));
      await tester.timedDragFrom(
        lower(page),
        const Offset(0, -300),
        const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.descendant(
        of: find.byType(V2ArticlePage).first,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable.first).position;
      expect(position.pixels, greaterThan(0));
      // One gesture that scrolls the article back past its top edge.
      await tester.timedDragFrom(
        Offset(page.center.dx, page.top + 80),
        Offset(0, position.pixels + 200),
        const Duration(milliseconds: 1200),
      );
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(refreshes, 0);

      await tester.timedDragFrom(
        center(page),
        const Offset(0, 320),
        const Duration(milliseconds: 450),
      );
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(refreshes, 1);
    });

    testWidgets('horizontal swipe still turns the page and never refreshes', (
      tester,
    ) async {
      await setPhone(tester);
      var refreshes = 0;
      final flip = PageFlipController();
      await tester.pumpWidget(
        _PullHarness(
          articles: [shortTa, shortEn, longTa],
          flip: flip,
          onRefresh: () async => refreshes++,
        ),
      );
      await tester.pump();
      final page = tester.getRect(find.byType(TurnablePage));
      await tester.timedDragFrom(
        Offset(page.right - page.width * 0.1, page.center.dy),
        Offset(-page.width * 0.7, 0),
        const Duration(milliseconds: 300),
      );
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(flip.currentPageIndex, 1);
      expect(refreshes, 0);
    });
  });
}

/// The Home body around the reader book, as built by V2ReaderHome: pull to
/// refresh over a full-height body scroll view, article pages with their
/// own scroll view inside V2PageTurn. [legacy] rebuilds the previous wiring
/// (default notification predicate, bouncing body scroll view).
class _PullHarness extends StatelessWidget {
  const _PullHarness({
    required this.articles,
    required this.onRefresh,
    this.legacy = false,
    this.flip,
  });

  final List<NewsArticle> articles;
  final Future<void> Function() onRefresh;
  final bool legacy;
  final PageFlipController? flip;

  @override
  Widget build(BuildContext context) {
    final controller = flip ?? PageFlipController();
    final book = V2PageTurn(
      controller: controller,
      itemCount: articles.length,
      index: 0,
      onIndexChanged: (_) {},
      itemBuilder: (context, i) => V2ArticlePage(
        article: articles[i],
        cutsLabel: 'NewsOn Cut',
        index: i,
        total: articles.length,
        bookmarked: false,
        onBookmark: () {},
        onShare: () {},
        onViewFullArticle: () {},
        onPrevious: () {},
        onNext: () {},
        showAdSlot: false,
        showHeroActions: false,
      ),
    );
    Widget body(BoxConstraints constraints) => SingleChildScrollView(
      physics: legacy
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
      child: SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: book,
      ),
    );
    return MaterialApp(
      home: Scaffold(
        body: legacy
            ? RefreshIndicator(
                onRefresh: onRefresh,
                child: LayoutBuilder(builder: (_, c) => body(c)),
              )
            : RefreshIndicator(
                onRefresh: onRefresh,
                notificationPredicate: v2ReaderPullNotificationPredicate,
                child: NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: v2ReaderSuppressTopOverscroll,
                  child: LayoutBuilder(builder: (_, c) => body(c)),
                ),
              ),
      ),
    );
  }
}
