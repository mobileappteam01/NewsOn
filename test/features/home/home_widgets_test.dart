import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/home/presentation/widgets/breaking_news_section.dart';
import 'package:newson/features/home/presentation/widgets/home_section_header.dart';
import 'package:newson/features/home/presentation/widgets/latest_news_card.dart';
import 'package:newson/features/home/presentation/widgets/news_cut_card.dart';
import 'package:newson/l10n/app_localizations.dart';

NewsArticle _sample() => NewsArticle(
      articleId: 'n1',
      newsId: 'n1',
      title: 'Sample headline for testing',
      link: 'https://example.com/n1',
      sourceName: 'Demo Publisher',
      pubDate: '2026-01-01T12:00:00.000Z',
      v2Summary: 'A short NewsOn Cut',
      summaryStatus: 'available',
      imageUrl: null,
    );

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );
}

void main() {
  testWidgets('HomeSectionHeader renders title', (tester) async {
    await tester.pumpWidget(
      _app(const HomeSectionHeader(title: 'Breaking News')),
    );
    expect(find.text('Breaking News'), findsOneWidget);
  });

  testWidgets('BreakingNewsSection shows article title', (tester) async {
    await tester.pumpWidget(
      _app(
        BreakingNewsSection(
          articles: [_sample()],
          autoScroll: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Sample headline'), findsOneWidget);
    expect(find.text('Demo Publisher'), findsWidgets);
  });

  testWidgets('LatestNewsCard exposes bookmark and share', (tester) async {
    await tester.pumpWidget(
      _app(
        LatestNewsCard(
          article: _sample(),
          onBookmark: () {},
          onShare: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
  });

  testWidgets('NewsCutsSection renders cut card', (tester) async {
    final config = RemoteConfigModel();
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: NewsCutsSection(
            articles: [_sample()],
            config: config,
            isBookmarked: (_) => false,
            onOpen: (_, __) {},
            onBookmark: (_) {},
            onShare: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Sample headline'), findsOneWidget);
    expect(find.textContaining('A short NewsOn Cut'), findsOneWidget);
  });

  testWidgets('HomeSectionError shows retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _app(
        HomeSectionError(
          message: 'Failed',
          onRetry: () => retried = true,
        ),
      ),
    );
    expect(find.text('Failed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
