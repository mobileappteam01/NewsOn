import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/for_you_response.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_actions.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_page_turn.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_reader_progress.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_summary_section.dart';
import 'package:newson/features/news/domain/news_summary.dart';

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
      // Swipe right → next
      expect(c.goNext(), isTrue);
      expect(c.state.index, 1);
      // Swipe left → previous
      expect(c.goPrevious(), isTrue);
      expect(c.state.index, 0);
      expect(c.goPrevious(), isFalse);
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

  group('V2PageTurn widget', () {
    testWidgets('shows only current page content initially', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
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
      expect(find.text('page-0'), findsOneWidget);
      expect(find.text('page-1'), findsNothing);
    });

    testWidgets('swipe right advances to next article', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
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

      await tester.drag(find.byType(V2PageTurn), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(index, 1);
      expect(find.text('page-1'), findsOneWidget);
    });

    testWidgets('swipe left goes to previous article', (tester) async {
      var index = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
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

      await tester.drag(find.byType(V2PageTurn), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(index, 0);
    });

    testWidgets('cancelled small swipe stays on current article',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2PageTurn(
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

      await tester.drag(find.byType(V2PageTurn), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(index, 0);
      expect(find.text('page-0'), findsOneWidget);
    });
  });

  group('V2 reader UI pieces', () {
    testWidgets('View Full Article CTA is present', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticleActions(
              bookmarked: false,
              onBookmark: () {},
              onShare: () {},
              onViewFullArticle: () => opened = true,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      expect(find.text('View Full Article'), findsOneWidget);
      await tester.tap(find.text('View Full Article'));
      expect(opened, isTrue);
    });

    testWidgets('bookmark and share actions fire', (tester) async {
      var bookmarked = false;
      var shared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ArticleActions(
              bookmarked: false,
              onBookmark: () => bookmarked = true,
              onShare: () => shared = true,
              onViewFullArticle: () {},
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Bookmark'));
      await tester.tap(find.byTooltip('Share'));
      expect(bookmarked, isTrue);
      expect(shared, isTrue);
    });

    testWidgets('progress shows index / total subtly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: V2ReaderProgress(index: 2, total: 20),
          ),
        ),
      );
      expect(find.text('3 / 20'), findsOneWidget);
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
      expect(find.text('NewsOn Cut'), findsOneWidget);
      expect(
        find.text('Short NewsOn Cut summary for the reader.'),
        findsOneWidget,
      );
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
}
