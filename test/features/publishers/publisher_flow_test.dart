import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/app/routing/v2_routes.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/core/analytics/analytics_service.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:newson/features/publishers/data/publisher_api.dart';
import 'package:newson/features/publishers/data/publisher_repository.dart';
import 'package:newson/features/publishers/domain/publisher_model.dart';
import 'package:newson/features/publishers/presentation/publisher_controller.dart';
import 'package:newson/features/publishers/presentation/publisher_page.dart';
import 'package:newson/features/publishers/presentation/publisher_state.dart';
import 'package:newson/features/publishers/presentation/widgets/publisher_attribution.dart';
import 'package:newson/providers/language_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';

NewsArticle _article({
  String id = 'aaaaaaaaaaaaaaaaaaaaaaaa',
  String? publisherId = '6ab2847e28ad7340b5d05ca2',
  String sourceName = 'Dinamaalai',
  String title = 'Headline',
}) {
  return NewsArticle(
    articleId: id,
    newsId: id,
    title: title,
    link: 'https://example.com/$id',
    sourceName: sourceName,
    publisherId: publisherId,
    pubDate: '2024-06-01 09:00:00',
    imageUrl: 'https://example.com/img.jpg',
    v2Summary: 'A short V2 summary.',
  );
}

class _FakePublisherRepo extends PublisherRepository {
  _FakePublisherRepo({
    this.publisher,
    this.pages = const [],
    this.throwOnResolve,
  });

  PublisherModel? publisher;
  List<PublisherNewsPage> pages;
  Object? throwOnResolve;

  final List<Map<String, dynamic>> fetchCalls = [];
  int resolveCount = 0;

  @override
  Future<PublisherModel> resolvePublisher({
    required String publisherKey,
    NewsArticle? seedArticle,
  }) async {
    resolveCount++;
    if (throwOnResolve != null) throw throwOnResolve!;
    return publisher ??
        PublisherModel(
          id: publisherKey,
          name: seedArticle?.publisherDisplayName ?? 'Dinamaalai',
          logoUrl: null,
        );
  }

  @override
  Future<PublisherNewsPage> fetchArticles({
    required PublisherModel publisher,
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    fetchCalls.add({
      'publisherId': publisher.id,
      'page': page,
      'limit': limit,
      'language': language,
    });
    if (pages.isEmpty) {
      return const PublisherNewsPage(
        articles: [],
        hasMore: false,
        page: 1,
        fromDedicatedEndpoint: true,
      );
    }
    final index = (page - 1).clamp(0, pages.length - 1);
    return pages[index];
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Publisher API mapping', () {
    test('maps publisher details correctly', () {
      final p = PublisherModel.fromJson({
        '_id': '6ab2847e28ad7340b5d05ca2',
        'name': 'Dinamaalai',
        'logoUrl': 'https://cdn.example/logo.png',
      });
      expect(p.id, '6ab2847e28ad7340b5d05ca2');
      expect(p.displayName, 'Dinamaalai');
      expect(p.logoUrl, 'https://cdn.example/logo.png');
      expect(p.displayName, isNot(equals('NewsData Aggregator')));
    });

    test('skips NewsData Aggregator as display name', () {
      final p = PublisherModel.fromJson({
        'id': '6ab2847e28ad7340b5d05ca2',
        'name': 'NewsData Aggregator',
        'source_name': 'Dinamaalai',
      });
      expect(p.displayName, 'Dinamaalai');
    });

    test('maps publisher news articles via V2FeedItemMapper', () {
      final page = V2FeedItemMapper.parseEnvelope({
        'success': true,
        'data': {
          'items': [
            {
              'articleId': 'bbbbbbbbbbbbbbbbbbbbbbbb',
              'title': 'Story One',
              'image': 'https://example.com/a.jpg',
              'publisher': {
                'id': '6ab2847e28ad7340b5d05ca2',
                'name': 'Dinamaalai',
              },
              'publishedAt': '2024-06-01T09:00:00Z',
              'v2Summary': 'Summary one',
              'source_name': 'Dinamaalai',
            },
          ],
          'page': 1,
          'limit': 20,
          'hasNextPage': true,
        },
      });
      expect(page.articles, hasLength(1));
      expect(page.articles.first.publisherId, '6ab2847e28ad7340b5d05ca2');
      expect(page.articles.first.publisherDisplayName, 'Dinamaalai');
      expect(page.articles.first.v2Summary, 'Summary one');
      expect(page.hasMore, isTrue);
      expect(
        page.articles.first.publisherDisplayName,
        isNot(equals('NewsData Aggregator')),
      );
    });

    test('hasNextPage false stops pagination signal', () {
      final page = V2FeedItemMapper.parseEnvelope({
        'data': {
          'items': [
            {
              'articleId': 'cccccccccccccccccccccccc',
              'title': 'Last',
              'source_name': 'Dinamaalai',
              'publisher': {'id': '6ab2847e28ad7340b5d05ca2', 'name': 'Dinamaalai'},
            },
          ],
          'page': 2,
          'hasNextPage': false,
        },
      });
      expect(page.hasMore, isFalse);
    });
  });

  group('Publisher attribution tapability', () {
    Widget wrap(Widget child, {bool publisherPages = true}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => RemoteConfigProvider.forTest(
              RemoteConfigModel(v2PublisherPagesEnabled: publisherPages),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider.forTest(newsLanguageCode: 'ta'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('publisher name is tappable when publisherId exists',
        (tester) async {
      final article = _article();
      await tester.pumpWidget(
        wrap(PublisherAttribution(article: article, sourceScreen: 'feed')),
      );
      expect(V2Routes.canOpenPublisher, isNotNull);
      final context = tester.element(find.byType(PublisherAttribution));
      expect(V2Routes.canOpenPublisher(context, article), isTrue);
      expect(find.text('Dinamaalai'), findsOneWidget);
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).onTap,
        isNotNull,
      );
    });

    testWidgets('publisher name is not tappable when publisherId missing',
        (tester) async {
      final article = _article(publisherId: null);
      await tester.pumpWidget(wrap(PublisherAttribution(article: article)));
      final context = tester.element(find.byType(PublisherAttribution));
      expect(V2Routes.canOpenPublisher(context, article), isFalse);
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Dinamaalai'), findsOneWidget);
    });

    testWidgets('all V2 surfaces off keeps publisher non-tappable even with id',
        (tester) async {
      final article = _article();
      await tester.pumpWidget(
        wrap(PublisherAttribution(article: article), publisherPages: false),
      );
      final context = tester.element(find.byType(PublisherAttribution));
      expect(V2Routes.canOpenPublisher(context, article), isFalse);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('V2 reader/detail flags enable publisher pages without RC key',
        (tester) async {
      final article = _article();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(
                  // Explicit publisher RC still false / missing demo case.
                  v2PublisherPagesEnabled: false,
                  v2HomeReaderEnabled: true,
                  v2NewArticleDetailEnabled: true,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider.forTest(newsLanguageCode: 'ta'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PublisherAttribution(
                article: article,
                sourceScreen: 'feed',
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(PublisherAttribution));
      expect(V2Routes.canOpenPublisher(context, article), isTrue);
      expect(find.byType(InkWell), findsOneWidget);
    });
  });

  group('Publisher controller pagination + language', () {
    test('passes language and stops when hasNextPage false', () async {
      final lang = LanguageProvider.forTest(newsLanguageCode: 'ta');
      final a1 = _article(id: '111111111111111111111111', title: 'One');
      final a2 = _article(id: '222222222222222222222222', title: 'Two');
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
        pages: [
          PublisherNewsPage(
            articles: [a1],
            hasMore: true,
            page: 1,
            fromDedicatedEndpoint: true,
          ),
          PublisherNewsPage(
            articles: [a2],
            hasMore: false,
            page: 2,
            fromDedicatedEndpoint: true,
          ),
        ],
      );
      final controller = PublisherController(
        repository: repo,
        languageProvider: lang,
      );

      await controller.open(publisherKey: '6ab2847e28ad7340b5d05ca2');
      expect(controller.state.status, PublisherLoadStatus.ready);
      expect(controller.state.articles, hasLength(1));
      expect(repo.fetchCalls.first['language'], 'ta');
      expect(repo.fetchCalls.first['page'], 1);

      await controller.loadMore();
      expect(controller.state.articles, hasLength(2));
      expect(controller.state.hasMore, isFalse);

      final callsBefore = repo.fetchCalls.length;
      await controller.loadMore();
      expect(repo.fetchCalls.length, callsBefore);
    });

    test('receives publisherId correctly on open', () async {
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
      );
      final controller = PublisherController(
        repository: repo,
        languageProvider: LanguageProvider.forTest(newsLanguageCode: 'en'),
      );
      await controller.open(publisherKey: '6ab2847e28ad7340b5d05ca2');
      expect(controller.state.publisher!.id, '6ab2847e28ad7340b5d05ca2');
      expect(controller.state.publisher!.displayName, 'Dinamaalai');
    });

    test('empty publisher news state', () async {
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
        pages: const [
          PublisherNewsPage(
            articles: [],
            hasMore: false,
            page: 1,
            fromDedicatedEndpoint: true,
          ),
        ],
      );
      final controller = PublisherController(
        repository: repo,
        languageProvider: LanguageProvider.forTest(),
      );
      await controller.open(publisherKey: '6ab2847e28ad7340b5d05ca2');
      expect(controller.state.articles, isEmpty);
      expect(controller.state.status, PublisherLoadStatus.ready);
    });

    test('publisher not-found state', () async {
      final repo = _FakePublisherRepo(
        throwOnResolve: StateError('missing_publisher'),
      );
      final controller = PublisherController(
        repository: repo,
        languageProvider: LanguageProvider.forTest(),
      );
      await controller.open(publisherKey: 'deadbeefdeadbeefdeadbeef');
      expect(controller.state.status, PublisherLoadStatus.error);
      expect(controller.state.errorCode, 'missing_publisher');
    });
  });

  group('Publisher page UI + navigation', () {
    testWidgets('shows original publisher name and empty copy', (tester) async {
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
        pages: const [
          PublisherNewsPage(
            articles: [],
            hasMore: false,
            page: 1,
            fromDedicatedEndpoint: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(v2PublisherPagesEnabled: true),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider.forTest(newsLanguageCode: 'ta'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: PublisherPage(
              publisherKey: '6ab2847e28ad7340b5d05ca2',
              repository: repo,
              sourceScreen: 'reader',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinamaalai'), findsWidgets);
      expect(find.text('Original Publisher'), findsOneWidget);
      expect(find.text('Latest News'), findsOneWidget);
      expect(
        find.text('No news available from this publisher yet.'),
        findsOneWidget,
      );
      expect(find.text('NewsData Aggregator'), findsNothing);
    });

    testWidgets('theme renders in dark mode', (tester) async {
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(v2PublisherPagesEnabled: true),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider.forTest(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: PublisherPage(
              publisherKey: '6ab2847e28ad7340b5d05ca2',
              repository: repo,
              sourceScreen: 'feed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dinamaalai'), findsWidgets);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNotNull);
    });

    testWidgets('article tap opens V2 article detail route', (tester) async {
      final article = _article();
      final repo = _FakePublisherRepo(
        publisher: const PublisherModel(
          id: '6ab2847e28ad7340b5d05ca2',
          name: 'Dinamaalai',
        ),
        pages: [
          PublisherNewsPage(
            articles: [article],
            hasMore: false,
            page: 1,
            fromDedicatedEndpoint: true,
          ),
        ],
      );
      final observer = _RouteObserver();

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(
                  v2PublisherPagesEnabled: true,
                  v2NewArticleDetailEnabled: true,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider.forTest(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            navigatorObservers: [observer],
            home: PublisherPage(
              publisherKey: '6ab2847e28ad7340b5d05ca2',
              repository: repo,
              sourceScreen: 'feed',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final headline = find.text('Headline');
      await tester.ensureVisible(headline);
      await tester.tap(headline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        observer.pushedNames,
        contains('/v2/article/${article.articleId}'),
      );
      expect(
        observer.pushedNames.any((n) => n.contains('news-detail')),
        isFalse,
      );
    });

    testWidgets('V2 openArticle never uses V1 detail when flag on',
        (tester) async {
      final observer = _RouteObserver();
      final article = _article();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(v2NewArticleDetailEnabled: true),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => V2Routes.openArticle(
                      context,
                      article: article,
                    ),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(
        observer.pushedNames,
        contains('/v2/article/${article.articleId}'),
      );
      expect(
        observer.pushedNames.any((n) => n.contains('news-detail')),
        isFalse,
      );
    });
  });

  group('Publisher analytics payload', () {
    test('publisher_click event name + track body metadata', () {
      expect(AnalyticsEvents.publisherClick, 'publisher_click');
      expect(AnalyticsEvents.publisherView, 'publisher_view');

      final body = AnalyticsService.buildTrackBody(
        eventName: AnalyticsEvents.publisherClick,
        sessionId: 'sess',
        platform: 'ios',
        params: {
          'publisherId': '6ab2847e28ad7340b5d05ca2',
          'publisherName': 'Dinamaalai',
          'language': 'tamil',
          'sourceScreen': 'reader',
        },
      );
      expect(body['eventName'], 'publisher_click');
      expect(body['publisherId'], '6ab2847e28ad7340b5d05ca2');
      expect(body['language'], 'tamil');
      final meta = body['metadata'] as Map<String, dynamic>;
      expect(meta['publisherName'], 'Dinamaalai');
      expect(meta['sourceScreen'], 'reader');
    });

    test('publisher_view includes language and sourceScreen', () {
      final body = AnalyticsService.buildTrackBody(
        eventName: AnalyticsEvents.publisherView,
        sessionId: 'sess',
        platform: 'android',
        params: {
          'publisherId': '6ab2847e28ad7340b5d05ca2',
          'language': 'hindi',
          'sourceScreen': 'feed',
        },
      );
      expect(body['language'], 'hindi');
      expect(
        (body['metadata'] as Map)['sourceScreen'],
        'feed',
      );
    });
  });
}

class _RouteObserver extends NavigatorObserver {
  final List<String> pushedNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushedNames.add(name);
  }
}
