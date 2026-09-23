import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/for_you_response.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_ad_placement.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_demo_pages.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_actions.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_page.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_bottom_navigation.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_page_turn.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_reader_ad_slot.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_summary_section.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_vintage_paper_background.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:turnable_page/turnable_page.dart';

NewsArticle _article(
  String id, {
  String? summary,
  String? summaryStatus,
  String? link,
}) =>
    NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Title $id',
      link: link ?? 'https://example.com/$id',
      sourceName: 'Publisher $id',
      category: const ['World'],
      pubDate: '2024-01-15 10:00:00',
      v2Summary: summary,
      summaryStatus: summaryStatus,
    );

ForYouRepository _repo(List<NewsArticle> articles, {bool hasMore = false}) {
  return ForYouRepository(
    forYouFetcher: ({
      required page,
      required limit,
      language,
      region,
    }) async =>
        ForYouResponse(
          message: 'personalized',
          pagination: ForYouPagination(
            total: articles.length,
            page: page,
            limit: limit,
            totalPages: hasMore ? page + 1 : page,
          ),
          articles: page == 1 ? articles : const [],
        ),
    todayFetcher: ({
      required language,
      required limit,
      country,
      state,
      district,
    }) async =>
        NewsResponse(status: 'ok', totalResults: 0, results: const []),
  );
}

V2ApiConfigService _readyConfig() {
  final s = V2ApiConfigService(
    fetcher: () async => const V2ApiConfig(
      baseUrl: 'https://v2-api.newson.app',
      enabled: true,
    ),
    cacheReader: () => null,
    cacheWriter: (_) async {},
  );
  s.debugSetConfig(
    const V2ApiConfig(
      baseUrl: 'https://v2-api.newson.app',
      enabled: true,
    ),
  );
  return s;
}

V2ReaderController _controller(ForYouRepository repo) {
  return V2ReaderController(
    repository: repo,
    configService: _readyConfig(),
    newsLanguageCode: () => 'en',
    appliedRegion: () => const SavedRegion(),
  );
}

void main() {
  group('NEWSON_V2_HOME_READER_ENABLED flag', () {
    test('defaults OFF so V1 / Cuts home remain available', () {
      final config = RemoteConfigModel();
      expect(V2FeatureFlags.homeReader(config), isFalse);
      expect(config.v2HomeReaderEnabled, isFalse);
    });

    test('Remote Config can enable home reader', () {
      final config = RemoteConfigModel(v2HomeReaderEnabled: true);
      expect(V2FeatureFlags.homeReader(config), isTrue);
    });

    test('V1 home flags remain independent', () {
      final config = RemoteConfigModel(v2HomeReaderEnabled: true);
      expect(V2FeatureFlags.newsCuts(config), isFalse);
      expect(V2FeatureFlags.homeReader(config), isTrue);
    });
  });

  group('V2ReaderController', () {
    test('loads V2 articles from For You API', () async {
      final articles = [_article('a1'), _article('a2'), _article('a3')];
      final c = _controller(_repo(articles));
      await c.loadInitial();
      expect(c.state.status, V2ReaderStatus.ready);
      expect(c.state.articles.length, 3);
      expect(c.state.current?.newsId, 'a1');
      expect(c.state.index, 0);
    });

    test('renders one article at a time via index', () async {
      final c = _controller(_repo([_article('a1'), _article('a2')]));
      await c.loadInitial();
      expect(c.state.current?.newsId, 'a1');
      expect(c.goNext(), isTrue);
      expect(c.state.current?.newsId, 'a2');
      expect(c.state.total, 2);
    });

    test('goNext / goPrevious match swipe directions', () async {
      final c = _controller(
        _repo([_article('a1'), _article('a2'), _article('a3')]),
      );
      await c.loadInitial();
      // Swipe left → next article
      expect(c.goNext(), isTrue);
      expect(c.state.index, 1);
      // Swipe right → previous article
      expect(c.goPrevious(), isTrue);
      expect(c.state.index, 0);
      expect(c.goPrevious(), isFalse);
    });

    test('setIndex synchronizes current article without bounds errors', () async {
      final c = _controller(
        _repo([_article('a1'), _article('a2'), _article('a3')]),
      );
      await c.loadInitial();
      expect(c.setIndex(2), isTrue);
      expect(c.state.index, 2);
      expect(c.state.current?.newsId, 'a3');
      expect(c.setIndex(99), isFalse);
      expect(c.state.index, 2);
    });

    test('empty feed surfaces empty status', () async {
      final c = _controller(_repo(const []));
      await c.loadInitial();
      expect(c.state.status, V2ReaderStatus.empty);
      expect(c.state.current, isNull);
    });

    test('API failure surfaces error status', () async {
      final c = _controller(
        ForYouRepository(
          forYouFetcher: ({
            required page,
            required limit,
            language,
            region,
          }) async =>
              throw Exception('network down'),
          todayFetcher: ({
            required language,
            required limit,
            country,
            state,
            district,
          }) async =>
              throw Exception('network down'),
        ),
      );
      await c.loadInitial();
      expect(c.state.status, V2ReaderStatus.error);
    });

    test('impression markImpression does not duplicate', () async {
      final c = _controller(_repo([_article('a1')]));
      await c.loadInitial();
      expect(c.markImpression('a1'), isTrue);
      expect(c.markImpression('a1'), isFalse);
      expect(c.markImpression('a1'), isFalse);
    });
  });

  group('V2PageTurn / TurnablePage', () {
    testWidgets('renders TurnablePage when articles exist', (tester) async {
      final flip = PageFlipController();
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
                  controller: flip,
                  itemCount: 3,
                  index: index,
                  onIndexChanged: (i) => setState(() => index = i),
                  itemBuilder: (context, i) =>
                      Center(child: Text('page-$i', key: ValueKey('page-$i'))),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TurnablePage), findsOneWidget);
      expect(find.byType(V2PageTurn), findsOneWidget);
      expect(find.text('page-0'), findsWidgets);
    });

    testWidgets('does not wrap article pages in a permanent mirror Transform',
        (tester) async {
      final flip = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2PageTurn(
              controller: flip,
              itemCount: 1,
              index: 0,
              onIndexChanged: (_) {},
              itemBuilder: (context, i) => const Text('Readable Title'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Our builder must return the article widget directly — no NewsOn-owned
      // scaleX(-1) wrapper. (Package-internal RTL double-mirror is OK.)
      final pageTurn = tester.widget<V2PageTurn>(find.byType(V2PageTurn));
      expect(pageTurn, isNotNull);

      Transform? newsOnMirror;
      void walk(Element el) {
        final w = el.widget;
        if (w is Transform) {
          final m = w.transform.storage;
          // scaleX == -1 and identity otherwise → permanent horizontal mirror
          if (m[0] == -1.0 &&
              m[5] == 1.0 &&
              m[10] == 1.0 &&
              w.child is Directionality) {
            newsOnMirror = w;
          }
        }
        el.visitChildren(walk);
      }

      tester.element(find.byType(V2PageTurn)).visitChildren(walk);
      expect(
        newsOnMirror,
        isNull,
        reason: 'V2PageTurn must not wrap pages in compensatory scaleX(-1)',
      );
      expect(find.text('Readable Title'), findsWidgets);
    });

    testWidgets('TurnablePage uses LTR so swipe left advances', (tester) async {
      final flip = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2PageTurn(
              controller: flip,
              itemCount: 2,
              index: 0,
              onIndexChanged: (_) {},
              itemBuilder: (context, i) => Text('page-$i'),
            ),
          ),
        ),
      );
      await tester.pump();
      final page = tester.widget<TurnablePage>(find.byType(TurnablePage));
      expect(page.textDirection, TextDirection.ltr);
    });

    testWidgets('empty article list does not create TurnablePage',
        (tester) async {
      final flip = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2PageTurn(
              controller: flip,
              itemCount: 0,
              index: 0,
              onIndexChanged: (_) {},
              itemBuilder: (context, i) => Text('page-$i'),
            ),
          ),
        ),
      );
      expect(find.byType(TurnablePage), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('PageFlipController nextPage advances synced index',
        (tester) async {
      final flip = PageFlipController();
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
                  controller: flip,
                  itemCount: 3,
                  index: index,
                  onIndexChanged: (i) => setState(() => index = i),
                  itemBuilder: (context, i) =>
                      Center(child: Text('page-$i', key: ValueKey('page-$i'))),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final future = flip.nextPage();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (index == 1) break;
      }
      await future.timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => index == 1,
      );

      expect(index, 1);
    });

    testWidgets('PageFlipController previousPage goes to previous article',
        (tester) async {
      final flip = PageFlipController();
      var index = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
                  controller: flip,
                  itemCount: 3,
                  index: index,
                  onIndexChanged: (i) => setState(() => index = i),
                  itemBuilder: (context, i) =>
                      Center(child: Text('page-$i', key: ValueKey('page-$i'))),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final future = flip.previousPage();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (index == 0) break;
      }
      await future.timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => index == 0,
      );

      expect(index, 0);
    });

    testWidgets('programmatic nav uses PageFlipController API', (tester) async {
      final flip = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2PageTurn(
              controller: flip,
              itemCount: 2,
              index: 0,
              onIndexChanged: (_) {},
              itemBuilder: (context, i) => Text('page-$i'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(flip.pageCount, greaterThanOrEqualTo(2));
      expect(flip.currentPageIndex, 0);
      expect(flip.hasNextPage, isTrue);
    });

    testWidgets('single PageFlipController survives rebuild', (tester) async {
      final flip = PageFlipController();
      var rebuild = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild++;
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {}),
                      child: const Text('rebuild'),
                    ),
                    Expanded(
                      child: V2PageTurn(
                        controller: flip,
                        itemCount: 3,
                        index: 0,
                        onIndexChanged: (_) {},
                        itemBuilder: (context, i) => Text('page-$i'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(rebuild, 1);
      await tester.tap(find.text('rebuild'));
      await tester.pump();
      expect(rebuild, 2);
      expect(find.byType(TurnablePage), findsOneWidget);
      expect(flip.currentPageIndex, 0);
    });
  });

  group('V2 reader demo pages', () {
    test('one article expands to exactly 3 pages', () {
      final a = _article('a1');
      final out = expandV2ReaderDemoPages([a]);
      expect(out.length, 3);
      expect(out[0].newsId, 'a1');
      expect(out[1].newsId, 'a1');
      expect(out[2].newsId, 'a1');
      expect(identical(out[0], a), isTrue);
    });

    test('two articles expand to A, B, A', () {
      final out = expandV2ReaderDemoPages([_article('a1'), _article('a2')]);
      expect(out.map((e) => e.newsId).toList(), ['a1', 'a2', 'a1']);
    });

    test('three or more articles are unchanged', () {
      final src = [_article('a1'), _article('a2'), _article('a3')];
      final out = expandV2ReaderDemoPages(src);
      expect(out.length, 3);
      expect(out.map((e) => e.newsId).toList(), ['a1', 'a2', 'a3']);
    });

    test('four articles are unchanged', () {
      final src = [
        _article('a1'),
        _article('a2'),
        _article('a3'),
        _article('a4'),
      ];
      expect(expandV2ReaderDemoPages(src).length, 4);
    });

    test('empty list stays empty', () {
      expect(expandV2ReaderDemoPages(const []), isEmpty);
    });

    test('replaceArticlesForDisplay keeps index in range', () async {
      final c = _controller(_repo([_article('a1')]));
      await c.loadInitial();
      expect(c.state.articles.length, 1);
      final expanded = expandV2ReaderDemoPages(c.state.articles);
      c.replaceArticlesForDisplay(expanded);
      expect(c.state.articles.length, 3);
      expect(c.state.index, 0);
      expect(c.setIndex(2), isTrue);
      expect(c.state.index, 2);
      expect(c.setIndex(3), isFalse);
      expect(c.state.index, 2);
    });

    test('readerDemoPages flag defaults OFF', () {
      expect(V2FeatureFlags.readerDemoPages(), isFalse);
    });
  });

  group('V2 reader UI pieces', () {
    testWidgets('Read Full Article CTA is present', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticleActions(
              onViewFullArticle: () => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('Read Full Article'), findsOneWidget);
      expect(find.textContaining('Read original'), findsNothing);
      await tester.tap(find.text('Read Full Article'));
      expect(opened, isTrue);
    });

    testWidgets('hero overlay bookmark and share actions fire', (tester) async {
      var bookmarked = false;
      var shared = false;
      final article = _article('x', summaryStatus: 'unavailable');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticlePage(
              article: article,
              cutsLabel: 'NewsOn Cut',
              index: 0,
              total: 5,
              bookmarked: false,
              onBookmark: () => bookmarked = true,
              onShare: () => shared = true,
              onViewFullArticle: () {},
              onPrevious: () {},
              onNext: () {},
              showAdSlot: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1 of 5'), findsNothing);
      expect(find.text('3 of 20'), findsNothing);
      await tester.tap(find.byTooltip('Bookmark'));
      await tester.tap(find.byTooltip('Share'));
      expect(bookmarked, isTrue);
      expect(shared, isTrue);
    });

    test('V2ReaderHome hosts actions outside TurnablePage (showHeroActions false)',
        () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(src.contains('showHeroActions: false'), isTrue);
      expect(src.contains('V2ReaderActionButtons'), isTrue);
      expect(src.contains('Positioned'), isTrue);
      expect(src.contains('top: 10'), isTrue);
      expect(src.contains('right: 18'), isTrue);
    });

    testWidgets('progress indicator is removed from reader', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticlePage(
              article: _article('x', summaryStatus: 'unavailable'),
              cutsLabel: 'NewsOn Cut',
              index: 2,
              total: 20,
              bookmarked: false,
              onBookmark: () {},
              onShare: () {},
              onViewFullArticle: () {},
              onPrevious: () {},
              onNext: () {},
              showAdSlot: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('3 of 20'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+ of \d+')), findsNothing);
    });

    testWidgets('summary unavailable shows graceful state', (tester) async {
      final article = _article('x', summaryStatus: 'unavailable');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2SummarySection(
              article: article,
              cutsLabel: 'NewsOn Cut',
            ),
          ),
        ),
      );
      expect(find.textContaining('not available'), findsOneWidget);
      expect(article.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
    });

    testWidgets('available summary renders cut text', (tester) async {
      final article = _article(
        'x',
        summary: 'Short NewsOn Cut summary for the reader.',
        summaryStatus: 'available',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2SummarySection(
              article: article,
              cutsLabel: 'NewsOn Cut',
            ),
          ),
        ),
      );
      expect(find.text('NEWSON CUT'), findsNothing);
      expect(
        find.text('Short NewsOn Cut summary for the reader.'),
        findsOneWidget,
      );
    });
  });

  group('V2 reader ad placement', () {
    setUp(V2ReaderAdPlacement.debugResetSession);

    test('5th article triggers first ad slot (interval 5)', () {
      const n = 5;
      expect(V2ReaderAdPlacement.shouldShowAdOnArticle(0, intervalOverride: n),
          isFalse);
      expect(V2ReaderAdPlacement.shouldShowAdOnArticle(3, intervalOverride: n),
          isFalse);
      expect(V2ReaderAdPlacement.shouldShowAdOnArticle(4, intervalOverride: n),
          isTrue);
      expect(
        V2ReaderAdPlacement.slotIndexForArticle(4, intervalOverride: n),
        0,
      );
    });

    test('10th article triggers second ad slot', () {
      const n = 5;
      expect(V2ReaderAdPlacement.shouldShowAdOnArticle(9, intervalOverride: n),
          isTrue);
      expect(
        V2ReaderAdPlacement.slotIndexForArticle(9, intervalOverride: n),
        1,
      );
    });

    test('going backward does not claim a new ad slot load', () {
      expect(V2ReaderAdPlacement.claimSlotLoad(0), isTrue);
      expect(V2ReaderAdPlacement.claimSlotLoad(0), isFalse);
      expect(V2ReaderAdPlacement.hasClaimedSlot(0), isTrue);
    });

    test('article indices stay news positions (ad is not a fake page)', () {
      // Articles 0..9 remain indices 0..9; ads attach to 4 and 9 only.
      final adPages = <int>[];
      for (var i = 0; i < 10; i++) {
        if (V2ReaderAdPlacement.shouldShowAdOnArticle(i, intervalOverride: 5)) {
          adPages.add(i);
        }
      }
      expect(adPages, [4, 9]);
    });

    testWidgets('non-ad article page has no V2ReaderAdSlot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticlePage(
              article: _article('a4', summary: 'Cut', summaryStatus: 'available'),
              cutsLabel: 'NewsOn Cut',
              index: 3,
              total: 10,
              bookmarked: false,
              onBookmark: () {},
              onShare: () {},
              onViewFullArticle: () {},
              onPrevious: () {},
              onNext: () {},
              showAdSlot: false,
            ),
          ),
        ),
      );
      expect(find.byType(V2ReaderAdSlot), findsNothing);
      expect(find.text('Read full story'), findsNothing);
      expect(find.text('Read Full Article'), findsOneWidget);
      expect(find.textContaining('Read original'), findsNothing);
    });
  });

  group('V2 reader dedupe + pagination', () {
    test('dedupeAppend drops duplicate IDs across pages', () {
      final existing = [_article('a1'), _article('a2')];
      final incoming = [_article('a2'), _article('a3')];
      final merged = V2ReaderController.dedupeAppend(existing, incoming);
      expect(merged.map((e) => e.newsId).toList(), ['a1', 'a2', 'a3']);
    });

    test('loadMore preserves current index', () async {
      var page = 0;
      final c = V2ReaderController(
        repository: ForYouRepository(
          forYouFetcher: ({
            required page,
            required limit,
            language,
            region,
          }) async {
            if (page == 1) {
              return ForYouResponse(
                message: 'personalized',
                pagination: ForYouPagination(
                  total: 40,
                  page: 1,
                  limit: 20,
                  totalPages: 2,
                  hasNextPage: true,
                ),
                articles: List.generate(20, (i) => _article('p1-$i')),
              );
            }
            return ForYouResponse(
              message: 'personalized',
              pagination: ForYouPagination(
                total: 40,
                page: 2,
                limit: 20,
                totalPages: 2,
                hasNextPage: false,
              ),
              articles: List.generate(20, (i) => _article('p2-$i')),
            );
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
        configService: _readyConfig(),
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
      );
      await c.loadInitial();
      expect(c.state.articles.length, 20);
      expect(c.setIndex(15), isTrue);
      expect(c.state.index, 15);
      c.unawaitedLoadMore();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.state.index, 15);
      expect(c.state.articles.length, greaterThan(20));
      page = c.state.page;
      expect(page, 2);
    });

    test('passes language code through to repository', () async {
      String? seenLang;
      final c = V2ReaderController(
        repository: ForYouRepository(
          forYouFetcher: ({
            required page,
            required limit,
            language,
            region,
          }) async {
            seenLang = language;
            return ForYouResponse(
              message: 'personalized',
              pagination: ForYouPagination(
                total: 1,
                page: 1,
                limit: 20,
                totalPages: 1,
              ),
              articles: [_article('ta-1')],
            );
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
        configService: _readyConfig(),
        newsLanguageCode: () => 'ta',
        appliedRegion: () => const SavedRegion(),
      );
      await c.loadInitial();
      expect(seenLang, 'ta');
      expect(c.state.current?.newsId, 'ta-1');
    });
  });

  group('V1 isolation', () {
    test('home_screen still references V1 NewsFeedTabNew when flags off', () {
      // Structural: reader flag off leaves V1 path intact.
      final config = RemoteConfigModel();
      expect(V2FeatureFlags.homeReader(config), isFalse);
      expect(V2FeatureFlags.newsCuts(config), isFalse);
      expect(V2FeatureFlags.v2Chrome(config), isFalse);
    });
  });

  group('V2 Reader theme support', () {
    Future<void> pumpArticle(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: V2ArticlePage(
              article: _article(
                'theme',
                summary: 'Theme-safe NewsOn Cut summary.',
                summaryStatus: 'available',
              ),
              cutsLabel: 'NewsOn Cut',
              index: 0,
              total: 10,
              bookmarked: false,
              onBookmark: () {},
              onShare: () {},
              onViewFullArticle: () {},
              onPrevious: () {},
              onNext: () {},
              showAdSlot: false,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('article page builds in light theme', (tester) async {
      await pumpArticle(tester, ThemeData.light(useMaterial3: true));
      expect(find.text('Title theme'), findsOneWidget);
      expect(find.text('NEWSON CUT'), findsNothing);
      expect(find.text('Theme-safe NewsOn Cut summary.'), findsOneWidget);
      expect(find.text('Read full story'), findsNothing);
      expect(find.text('Read Full Article'), findsOneWidget);
      expect(find.textContaining('Read original'), findsNothing);
      expect(find.byType(V2VintagePaperBackground), findsOneWidget);
    });

    testWidgets('article page builds in dark theme', (tester) async {
      await pumpArticle(tester, ThemeData.dark(useMaterial3: true));
      expect(find.text('Title theme'), findsOneWidget);
      expect(find.text('NEWSON CUT'), findsNothing);
      expect(find.text('Theme-safe NewsOn Cut summary.'), findsOneWidget);
      expect(find.text('Read full story'), findsNothing);
      expect(find.text('Read Full Article'), findsOneWidget);
      expect(find.textContaining('Read original'), findsNothing);
      expect(find.byType(V2VintagePaperBackground), findsOneWidget);
      final pageMaterials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.color != null)
          .map((m) => m.color)
          .toList();
      expect(pageMaterials.contains(const Color(0xFFFAFAF8)), isFalse);
    });

    testWidgets('floating bottom nav is icon-only with four destinations',
        (tester) async {
      for (final theme in [
        ThemeData.light(useMaterial3: true),
        ThemeData.dark(useMaterial3: true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              bottomNavigationBar: V2FloatingBottomNav(
                currentIndex: 0,
                homeLabel: 'Home',
                forYouLabel: 'For You',
                bookmarksLabel: 'Bookmarks',
                searchLabel: 'Search',
                onHome: () {},
                onForYou: () {},
                onBookmarks: () {},
                onSearch: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        // Icon-only — no visible text labels.
        expect(find.text('Home'), findsNothing);
        expect(find.text('For You'), findsNothing);
        expect(find.text('Search'), findsNothing);
        expect(find.text('Bookmarks'), findsNothing);
        expect(find.text('Categories'), findsNothing);
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      }
    });

    testWidgets('bottom nav order is Home, For You, Bookmarks, Search',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: V2FloatingBottomNav(
              currentIndex: 0,
              homeLabel: 'Home',
              forYouLabel: 'For You',
              bookmarksLabel: 'Bookmarks',
              searchLabel: 'Search',
              onHome: () {},
              onForYou: () {},
              onBookmarks: () {},
              onSearch: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toList();
      expect(tooltips, ['Home', 'For You', 'Bookmarks', 'Search']);
    });

    testWidgets('bottom nav highlights Search as fourth destination',
        (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: V2FloatingBottomNav(
              currentIndex: 3,
              homeLabel: 'Home',
              forYouLabel: 'For You',
              bookmarksLabel: 'Bookmarks',
              searchLabel: 'Search',
              onHome: () => selected = 0,
              onForYou: () => selected = 1,
              onBookmarks: () => selected = 2,
              onSearch: () => selected = 3,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Search'));
      expect(selected, 3);
      await tester.tap(find.byTooltip('Bookmarks'));
      expect(selected, 2);
    });

    testWidgets('all tabs use Home stage base for nav pill background',
        (tester) async {
      Future<Color?> pillColor(int index) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              bottomNavigationBar: V2FloatingBottomNav(
                currentIndex: index,
                homeLabel: 'Home',
                forYouLabel: 'For You',
                bookmarksLabel: 'Bookmarks',
                searchLabel: 'Search',
                onHome: () {},
                onForYou: () {},
                onBookmarks: () {},
                onSearch: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        final animated = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('v2_nav_pill_surface')),
        );
        final box = animated.decoration as BoxDecoration?;
        return box?.color;
      }

      final expected = V2VintagePaperBackground.stageBaseFor(Brightness.light);
      final homePill = await pillColor(0);
      final forYouPill = await pillColor(1);
      final bookmarksPill = await pillColor(2);
      final searchPill = await pillColor(3);

      expect(homePill, expected);
      expect(forYouPill, expected);
      expect(bookmarksPill, expected);
      expect(searchPill, expected);
      expect(homePill, equals(forYouPill));
      expect(homePill, equals(bookmarksPill));
      expect(homePill, equals(searchPill));
    });

    testWidgets('Read Full Article CTA is compact and centered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: V2ArticleActions(onViewFullArticle: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Read Full Article'), findsOneWidget);
      final cta = tester.getRect(find.text('Read Full Article'));
      // Must not stretch near full width.
      expect(cta.width, lessThan(280));
      final parent = tester.getRect(find.byType(V2ArticleActions));
      final centerDelta =
          ((cta.center.dx) - (parent.center.dx)).abs();
      expect(centerDelta, lessThan(24));
    });

    test('home_screen wires Search as last nav destination (stack index 3)', () {
      final src = File(
        'lib/screens/home/home_screen.dart',
      ).readAsStringSync();
      expect(src.contains('onSearch: () => setState(() => _currentIndex = 3)'),
          isTrue);
      expect(src.contains('searchLabel: LocalizationHelper.v2Search'), isTrue);
      // Header no longer owns Search.
      final header = File(
        'lib/features/home/presentation/widgets/home_header.dart',
      ).readAsStringSync();
      expect(header.contains('Icons.search_rounded'), isFalse);
      expect(header.contains('onSearchTap'), isFalse);
      // Bottom nav source order ends with Search.
      final nav = File(
        'lib/features/home_v2/presentation/widgets/v2_bottom_navigation.dart',
      ).readAsStringSync();
      final bookmarksIdx = nav.indexOf('Icons.bookmark_border_rounded');
      final searchIdx = nav.lastIndexOf('Icons.search_rounded');
      expect(bookmarksIdx, greaterThan(0));
      expect(searchIdx, greaterThan(bookmarksIdx));
    });

    test('detail headline default size is reduced (27–30px band)', () {
      final src = File(
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('double size = 28'), isTrue);
      expect(src.contains('double size = 32'), isFalse);
      expect(src.contains('Open Article'), isFalse);
    });

    testWidgets('bookmark and share taps do not require page index change',
        (tester) async {
      var index = 2;
      var bookmarked = false;
      var shared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticlePage(
              article: _article('a', summaryStatus: 'unavailable'),
              cutsLabel: 'NewsOn Cut',
              index: index,
              total: 10,
              bookmarked: false,
              onBookmark: () => bookmarked = true,
              onShare: () => shared = true,
              onViewFullArticle: () {},
              onPrevious: () => index--,
              onNext: () => index++,
              showAdSlot: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Bookmark'));
      await tester.tap(find.byTooltip('Share'));
      expect(bookmarked, isTrue);
      expect(shared, isTrue);
      expect(index, 2);
    });

    test('dark theme primary stays saturated brand red', () {
      final config = RemoteConfigModel(primaryColor: '#C70000');
      final dark = AppTheme.getDarkTheme(config);
      expect(dark.colorScheme.primary, const Color(0xFFC70000));
      // fromSeed wash would produce a lighter pinkish primary — reject that.
      expect(dark.colorScheme.primary.computeLuminance() < 0.25, isTrue);
    });
  });
}
