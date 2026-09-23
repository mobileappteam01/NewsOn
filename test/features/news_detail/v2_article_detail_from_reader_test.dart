import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:newson/features/news_detail/data/v2_article_detail_api.dart';
import 'package:newson/features/news_detail/domain/v2_article_body_resolver.dart';
import 'package:newson/features/news_detail/presentation/v2_article_detail_screen.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';

class _FakeDetailApi extends V2ArticleDetailApi {
  _FakeDetailApi({
    this.article,
    this.error,
    this.delay = Duration.zero,
  });

  NewsArticle? article;
  Object? error;
  final Duration delay;
  int fetchCount = 0;
  String? lastId;

  @override
  Future<NewsArticle> fetch(String articleId) async {
    fetchCount++;
    lastId = articleId;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) throw error!;
    final a = article;
    if (a == null) {
      throw V2ArticleDetailException('invalid_payload');
    }
    return a;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  NewsArticle sampleArticle({
    String? content,
    String? description,
    String? v2Summary,
    String? link,
  }) =>
      NewsArticle(
        articleId: 'v2-detail-1',
        newsId: 'v2-detail-1',
        title: 'V2 Detail Headline About Markets',
        imageUrl: 'https://example.com/hero.jpg',
        sourceName: 'Example Gazette',
        category: const ['Business'],
        pubDate: '2024-06-01 09:00:00',
        content: content ??
            'First paragraph of the full stored article.\n\n'
                'Second paragraph continues the story with more detail.',
        description: description,
        v2Summary: v2Summary ?? 'Markets rose after the policy announcement.',
        summaryStatus: 'available',
        link: link ?? 'https://publisher.example/story/markets',
      );

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RemoteConfigProvider.forTest(RemoteConfigModel()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('V2ArticleBodyResolver', () {
    test('prefers content over description and never v2Summary', () {
      final a = sampleArticle(
        content: 'Full body content',
        description: 'Short description',
        v2Summary: 'Sixty word cut',
      );
      expect(V2ArticleBodyResolver.rawBody(a), 'Full body content');
    });

    test('falls back to description when content missing', () {
      final a = NewsArticle(
        articleId: 'd1',
        newsId: 'd1',
        title: 'T',
        description: 'Description body',
        v2Summary: 'Cut text',
      );
      expect(V2ArticleBodyResolver.rawBody(a), 'Description body');
    });

    test('ignores paid-plan placeholder content', () {
      final a = NewsArticle(
        articleId: 'd2',
        newsId: 'd2',
        title: 'T',
        content: 'ONLY AVAILABLE IN PAID PLANS',
        description: 'Use description instead',
        v2Summary: 'Cut',
      );
      expect(V2ArticleBodyResolver.rawBody(a), 'Use description instead');
    });

    test('returns null when only v2Summary is present', () {
      final a = NewsArticle(
        articleId: 'd3',
        newsId: 'd3',
        title: 'T',
        v2Summary: 'Cut only',
      );
      expect(V2ArticleBodyResolver.rawBody(a), isNull);
    });

    test('splits paragraphs on blank lines', () {
      expect(
        V2ArticleBodyResolver.paragraphs('One.\n\nTwo.\n\nThree.'),
        ['One.', 'Two.', 'Three.'],
      );
    });
  });

  group('V2FeedItemMapper content aliases', () {
    test('maps content and description from feed item', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'map-1',
        'title': 'Mapped',
        'content': 'Stored full article',
        'description': 'Excerpt',
        'v2Summary': 'Cut',
        'link': 'https://example.com/a',
        'publisher': {'name': 'Pub'},
      });
      expect(article, isNotNull);
      expect(article!.content, 'Stored full article');
      expect(article.description, 'Excerpt');
      expect(article.v2Summary, 'Cut');
    });

    test('maps full_content alias into content', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'map-2',
        'title': 'Alias',
        'full_content': 'Aliased body',
        'link': 'https://example.com/b',
      });
      expect(article?.content, 'Aliased body');
    });

    test('maps detail API fields preferring original source over aggregator',
        () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': '6ab1d4fda5abc256076d157e',
        'title': 'Detail Title',
        'content': '<p>Full HTML body</p>',
        'description': 'Desc',
        'v2Summary': 'Cut',
        'summarySource': 'v2',
        'sourceName': 'The Hindu',
        'source_id': 'the-hindu',
        'image': 'https://example.com/i.jpg',
        'canonicalUrl': 'https://publisher.example/story',
        'publishedAt': '2026-03-22T10:00:00.000Z',
        'category': [
          {'id': 'c1', 'name': 'politics'},
        ],
        'publisher': {
          'id': 'p1',
          'name': 'NewsData Aggregator',
        },
      });
      expect(article, isNotNull);
      expect(article!.content, '<p>Full HTML body</p>');
      expect(article.sourceName, 'The Hindu');
      expect(article.publisherDisplayName, 'The Hindu');
      expect(article.publisherDisplayName, isNot(equals('NewsData Aggregator')));
      expect(article.summaryStatus, 'v2');
      expect(article.link, 'https://publisher.example/story');
      expect(article.imageUrl, 'https://example.com/i.jpg');
      expect(article.category, ['politics']);
    });

    test('does not use NewsData Aggregator when original publisher exists', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'abc',
        'title': 'T',
        'source_name': 'Nakkeeran',
        'publisher': {'id': 'nd', 'name': 'NewsData Aggregator'},
      });
      expect(article!.publisherDisplayName, 'Nakkeeran');
      expect(article.sourceName, 'Nakkeeran');
    });

    test('skips NewsData Aggregator when it is the only publisher label', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'abc',
        'title': 'T',
        'publisher': {'id': 'nd', 'name': 'NewsData Aggregator'},
        'sourceName': 'NewsData Aggregator',
      });
      expect(article!.sourceName, isNull);
      expect(article.publisherDisplayName, 'Publisher');
      expect(article.publisherDisplayName, isNot(contains('NewsData')));
    });
  });

  group('V2ArticleDetailScreen', () {
    testWidgets('fetches by articleId and renders full content, not v2Summary',
        (tester) async {
      final article = sampleArticle(
        content: 'Full article paragraph for detail.',
        v2Summary: 'This cut must not appear as body',
      );
      final api = _FakeDetailApi(article: article);
      await tester.pumpWidget(
        wrap(
          V2ArticleDetailScreen(
            articleId: article.articleId!,
            seedArticle: NewsArticle(
              articleId: article.articleId,
              newsId: article.newsId,
              title: article.title,
              v2Summary: 'This cut must not appear as body',
              link: article.link,
            ),
            detailApi: api,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(api.fetchCount, 1);
      expect(api.lastId, 'v2-detail-1');
      expect(find.text('V2 Detail Headline About Markets'), findsOneWidget);
      expect(find.text('Full article paragraph for detail.'), findsOneWidget);
      expect(find.text('This cut must not appear as body'), findsNothing);
      expect(find.textContaining('View Full Article'), findsNothing);
      expect(find.textContaining('Read Full Story'), findsNothing);
      expect(find.textContaining('Summary unavailable'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byTooltip('Bookmark'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsNothing);
      expect(find.text('Open Article'), findsNothing);
      expect(find.textContaining('Open Article'), findsNothing);
      // Bookmark + Share paired in the same hero action cluster.
      final bookmark = tester.getCenter(find.byTooltip('Bookmark'));
      final share = tester.getCenter(find.byTooltip('Share'));
      expect((share.dx - bookmark.dx).abs(), lessThan(60));
      expect((share.dy - bookmark.dy).abs(), lessThan(8));
    });

    testWidgets('empty body never shows Summary unavailable', (tester) async {
      final article = NewsArticle(
        articleId: 'empty-body',
        newsId: 'empty-body',
        title: 'Empty body story',
        link: 'https://publisher.example/x',
        v2Summary: 'Cut should not fill body',
      );
      final api = _FakeDetailApi(article: article);
      await tester.pumpWidget(
        wrap(
          V2ArticleDetailScreen(
            articleId: 'empty-body',
            detailApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Modi's war"), findsNothing);
      expect(find.textContaining('Peter Navarro'), findsNothing);
      expect(find.text('Cut should not fill body'), findsNothing);
      expect(find.textContaining('Summary unavailable'), findsNothing);
      expect(
        find.textContaining('Unable to load article content'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsNothing);
    });

    testWidgets('shows error with retry on fetch failure', (tester) async {
      final api = _FakeDetailApi(
        error: V2ArticleDetailException('not_found', statusCode: 404),
      );
      await tester.pumpWidget(
        wrap(
          V2ArticleDetailScreen(
            articleId: 'missing-id',
            detailApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Article not found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      api.error = null;
      api.article = sampleArticle(content: 'Recovered full body');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered full body'), findsOneWidget);
      expect(api.fetchCount, 2);
    });

    testWidgets('never shows V1 mock Navarro fallback body', (tester) async {
      final article = NewsArticle(
        articleId: 'empty-body-2',
        newsId: 'empty-body-2',
        title: 'Empty body story 2',
        link: 'https://publisher.example/x',
        v2Summary: 'Cut should not fill body',
      );
      await tester.pumpWidget(
        wrap(
          V2ArticleDetailScreen(
            articleId: 'empty-body-2',
            detailApi: _FakeDetailApi(article: article),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Modi's war"), findsNothing);
      expect(find.textContaining('Peter Navarro'), findsNothing);
    });

    testWidgets('back returns to previous route', (tester) async {
      final article = sampleArticle();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  RemoteConfigProvider.forTest(RemoteConfigModel()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => V2ArticleDetailScreen(
                            articleId: article.articleId!,
                            seedArticle: article,
                            detailApi: _FakeDetailApi(article: article),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open detail'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('V2 Detail Headline About Markets'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
      expect(find.text('V2 Detail Headline About Markets'), findsNothing);
    });

    testWidgets('builds in dark theme', (tester) async {
      final article = sampleArticle();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  RemoteConfigProvider.forTest(RemoteConfigModel()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: V2ArticleDetailScreen(
              articleId: article.articleId!,
              detailApi: _FakeDetailApi(article: article),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('V2 Detail Headline About Markets'), findsOneWidget);
      expect(find.textContaining('First paragraph'), findsOneWidget);
    });
  });

  group('Reader Read Original → V2 detail contract', () {
    test('V2ReaderHome navigates to V2ArticleDetailScreen with articleId', () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(src.contains('V2ArticleDetailScreen'), isTrue);
      expect(src.contains('articleId:'), isTrue);
      expect(src.contains('FullArticleScreen'), isFalse);
      expect(src.contains('getNewsByIdMobile'), isFalse);
    });

    test('V2 detail fetches V2 article endpoint, no V1 APIs', () {
      final src = File(
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('V2ArticleDetailApi'), isTrue);
      expect(src.contains('NewsProvider'), isFalse);
      expect(src.contains('NewsDetailScreen'), isFalse);
      expect(src.contains('NewsRepository'), isFalse);
      expect(src.contains('screens/news_detail'), isFalse);
      expect(src.contains('FullArticleScreen'), isFalse);
      expect(src.contains('v2ViewFullArticle'), isFalse);
      expect(src.contains('v2SummaryUnavailable'), isFalse);
      expect(src.contains('V2ArticleBodyResolver'), isTrue);
      expect(src.contains('newsOnCutText'), isFalse);
      expect(src.contains('Icons.share_rounded'), isTrue);
      expect(src.contains('Icons.share_outlined'), isFalse);
      expect(src.contains('api.newson.app'), isFalse);
      expect(src.contains('getNewsByIdMobile'), isFalse);
      expect(src.contains('toggleBookmarkV2'), isTrue);
      expect(src.contains('addBookmark'), isFalse);
    });

    test('V2ArticleDetailApi uses /api/v2/article and useV2Host', () {
      final src = File(
        'lib/features/news_detail/data/v2_article_detail_api.dart',
      ).readAsStringSync();
      expect(src.contains("/api/v2/article"), isTrue);
      expect(src.contains('useV2Host: true'), isTrue);
      expect(src.contains('api.newson.app'), isFalse);
      expect(src.contains('getNewsByIdMobile'), isFalse);
    });

    test('InteractionService routes to V2 /api/interaction when V2 ready', () {
      final src = File(
        'lib/data/services/interaction_service.dart',
      ).readAsStringSync();
      expect(src.contains("v2InteractionPath = '/api/interaction'"), isTrue);
      expect(src.contains('useV2Host: true'), isTrue);
      expect(src.contains('V2ApiConfigService'), isTrue);
    });
  });
}
