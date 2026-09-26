import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/bookmark_api_service.dart';
import 'package:newson/features/bookmarks/presentation/v2_bookmark_list_tile.dart';

void main() {
  const articleId = '66f0c1a2b3c4d5e6f7a8b9c0';

  NewsArticle v2ListArticle() {
    final parsed = BookmarkListResponse.fromV2Data({
      'items': [
        {
          'articleId': articleId,
          '_id': articleId,
          'title': 'Bookmarked story',
          'publishedAt': '2026-09-23T10:00:00.000Z',
        },
      ],
      'page': 1,
      'limit': 20,
      'hasNextPage': false,
    });
    return parsed.data.single;
  }

  test('refreshed V2 bookmark item has a null category', () {
    final article = v2ListArticle();
    expect(article.newsId, articleId);
    expect(article.category, isNull);
  });

  testWidgets(
    'V2 bookmark row renders one item without remote config or category',
    (tester) async {
      final article = v2ListArticle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2BookmarkListTile(
              article: article,
              bookmarked: true,
              onOpen: () {},
              onBookmark: () {},
              onShare: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bookmarked story'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh rebuild with the same null category does not crash', (
    tester,
  ) async {
    final article = v2ListArticle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2BookmarkListTile(
            article: article,
            bookmarked: true,
            onOpen: () {},
            onBookmark: () {},
            onShare: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2BookmarkListTile(
            article: article,
            bookmarked: true,
            onOpen: () {},
            onBookmark: () {},
            onShare: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Bookmarked story'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('V1 NewsGridView still force-unwraps category; V2 tab does not use it', () {
    final grid = File('lib/widgets/news_grid_views.dart').readAsStringSync();
    expect(grid.contains('newsDetails.category!'), isTrue);
    final tab = File('lib/screens/bookmarks/bookmarks_tab.dart').readAsStringSync();
    final v2Tile = tab.indexOf('V2BookmarkListTile(');
    final v1Grid = tab.indexOf('return NewsGridView(');
    expect(v2Tile, greaterThan(0));
    expect(v1Grid, greaterThan(v2Tile));
    expect(tab.contains('if (_v2Bookmarks(context))'), isTrue);
  });
}
