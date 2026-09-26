import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/bookmark_api_service.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/bookmarks/domain/bookmark_list_state.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _article(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

void main() {
  group('category slug serialization', () {
    test('uses the API slug, not the display name or ObjectId', () {
      const objectId = '66f0c1a2b3c4d5e6f7a8b9c0';
      final option = V2CategoryOption.fromJson({
        '_id': objectId,
        'id': objectId,
        'categoryName': 'Technology',
        'name': 'technology',
      });
      expect(option.slug, 'technology');
      expect(option.name, 'Technology');
      expect(isMongoObjectId(objectId), isTrue);

      final query = const HomeFilterState(selectedCategorySlugs: ['technology'])
          .toQueryParameters(language: 'ta', page: 1, limit: 20);
      expect(query['category'], 'technology');
      expect(query['category']!.contains(objectId), isFalse);
      expect(query['category'], isNot('Technology'));
    });

    test('single category apply sends category slug and page 1', () {
      final query = const HomeFilterState(selectedCategorySlugs: ['sports'])
          .toQueryParameters(language: 'en', page: 1, limit: 20);
      expect(query['category'], 'sports');
      expect(query['page'], '1');
      expect(query.containsKey('categoryName'), isFalse);
    });

    test('multiple categories are comma-joined slugs', () {
      final query = const HomeFilterState(
        selectedCategorySlugs: ['technology', 'sports'],
      ).toQueryParameters(language: 'ta', page: 1, limit: 20);
      expect(query['category'], 'technology,sports');
    });

    test('category apply keeps language', () {
      final query = const HomeFilterState(selectedCategorySlugs: ['business'])
          .toQueryParameters(language: 'ta', page: 1, limit: 20);
      expect(query['category'], 'business');
      expect(query['language'], 'ta');
    });

    test('category apply keeps location filters', () {
      final query = const HomeFilterState(
        selectedCategorySlugs: ['technology'],
        country: 'india',
        state: 'tamil-nadu',
        district: 'coimbatore',
      ).toQueryParameters(language: 'ta', page: 1, limit: 20);
      expect(query['category'], 'technology');
      expect(query['language'], 'ta');
      expect(query['country'], 'india');
      expect(query['state'], 'tamil-nadu');
      expect(query['city'], 'coimbatore');
    });

    test('explicit slug wins over a slug-shaped name', () {
      final option = V2CategoryOption.fromJson({
        'slug': 'sports',
        'name': 'games',
        'categoryName': 'Sports',
      });
      expect(option.slug, 'sports');
      expect(option.name, 'Sports');
    });
  });

  group('category apply replaces the feed', () {
    test('empty category response does not keep the previous articles', () async {
      var slugs = const <String>[];
      final controller = V2ReaderController(
        newsLanguageCode: () => 'ta',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => HomeFilterState(selectedCategorySlugs: slugs),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          expect(page, 1);
          expect(language, 'ta');
          if (filter.selectedCategorySlugs.isEmpty) {
            return V2FeedPage(
              articles: [_article('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          expect(filter.selectedCategorySlugs, ['technology']);
          return const V2FeedPage(articles: [], page: 1, hasMore: false);
        },
      );

      await controller.loadInitial();
      expect(controller.state.articles, isNotEmpty);
      slugs = const ['technology'];
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.empty);
      expect(controller.state.articles, isEmpty);
    });

    test('a stale next page does not append after a new category load', () async {
      final gate = Completer<void>();
      final controller = V2ReaderController(
        newsLanguageCode: () => 'ta',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () =>
            const HomeFilterState(selectedCategorySlugs: ['technology']),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          if (page > 1) {
            await gate.future;
            return V2FeedPage(
              articles: [_article('bbbbbbbbbbbbbbbbbbbbbbbb')],
              page: page,
              hasMore: false,
            );
          }
          return V2FeedPage(
            articles: [_article('aaaaaaaaaaaaaaaaaaaaaaaa')],
            page: 1,
            hasMore: true,
          );
        },
      );

      await controller.loadInitial();
      controller.unawaitedLoadMore();
      await Future<void>.delayed(Duration.zero);
      await controller.loadInitial();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.articles.map((a) => a.newsId),
        ['aaaaaaaaaaaaaaaaaaaaaaaa'],
      );
    });
  });

  group('bookmark list', () {
    final article = _article('aaaaaaaaaaaaaaaaaaaaaaaa');
    final other = _article('bbbbbbbbbbbbbbbbbbbbbbbb');

    test('bookmark create is visible', () {
      final visible = BookmarkListEdits.add(const [], article);
      expect(visible.single.newsId, article.newsId);
    });

    test('bookmark survives refresh when the API returns it', () {
      final created = BookmarkListEdits.add(const [], article);
      final refreshed = BookmarkRefreshResult.success(created);
      expect(refreshed.phase, BookmarkListPhase.withData);
      expect(refreshed.items.single.newsId, article.newsId);
    });

    test('detail back does not reconstruct an empty list', () {
      final visible = BookmarkListEdits.add(const [], article);
      final src = File('lib/screens/bookmarks/bookmarks_tab.dart').readAsStringSync();
      expect(src.contains('BookmarkProvider('), isFalse);
      expect(src.contains('AutomaticKeepAliveClientMixin'), isTrue);
      expect(visible, isNotEmpty);
    });

    test('failed refresh preserves the existing list and is not empty', () {
      final visible = [article, other];
      final failed = BookmarkRefreshResult.failure(
        visible: visible,
        error: 'Could not refresh bookmarks',
      );
      expect(failed.isError, isTrue);
      expect(failed.phase, BookmarkListPhase.error);
      expect(failed.items.length, 2);
      expect(failed.phase, isNot(BookmarkListPhase.empty));
    });

    test('successful empty response is empty, not an error', () {
      final empty = BookmarkRefreshResult.success(const []);
      expect(empty.phase, BookmarkListPhase.empty);
      expect(empty.items, isEmpty);
      expect(empty.error, isNull);
      expect(empty.isError, isFalse);
    });

    test('duplicate toggle is ignored while one request is in flight', () {
      final guard = BookmarkToggleGuard();
      expect(guard.tryBegin(article.newsId!), isTrue);
      expect(guard.tryBegin(article.newsId!), isFalse);
      guard.end(article.newsId!);
      expect(guard.tryBegin(article.newsId!), isTrue);
    });

    test('unbookmark stays removed after a successful refresh', () {
      final bookmarked = BookmarkListEdits.add(const [], article);
      final removed = BookmarkListEdits.remove(bookmarked, article.newsId!);
      expect(removed, isEmpty);
      final refreshed = BookmarkRefreshResult.success(removed);
      expect(refreshed.phase, BookmarkListPhase.empty);
      expect(refreshed.items, isEmpty);
    });

    test('failed unbookmark rolls the article back into the list', () {
      final bookmarked = BookmarkListEdits.add(const [], article);
      final removed = BookmarkListEdits.remove(bookmarked, article.newsId!);
      final rolledBack = BookmarkListEdits.add(removed, article);
      expect(rolledBack.single.newsId, article.newsId);
    });
  });

  group('V2 bookmark persistence contract', () {
    const articleId = '66f0c1a2b3c4d5e6f7a8b9c0';

    test('GET items parse as the bookmarked article', () {
      final parsed = BookmarkListResponse.fromV2Data({
        'items': [
          {
            'articleId': articleId,
            '_id': articleId,
            'title': 'Article A',
          },
        ],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      expect(parsed.data.single.newsId, articleId);
      expect(parsed.data.single.title, 'Article A');
      expect(parsed.pagination.hasMore, isFalse);
    });

    test('successful empty items stay an empty list', () {
      final parsed = BookmarkListResponse.fromV2Data({
        'items': [],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      expect(parsed.data, isEmpty);
    });

    test('ADD posts /api/v2/bookmarks before interaction tracking', () {
      final provider = File('lib/providers/bookmark_provider.dart').readAsStringSync();
      final api = File('lib/data/services/bookmark_api_service.dart').readAsStringSync();
      final start = provider.indexOf('Future<bool> toggleBookmarkV2');
      final method = provider.substring(
        start,
        provider.indexOf('Future<bool> _toggleBookmarkLocal', start),
      );
      final addAt = method.indexOf('addV2Bookmark');
      final trackAt = method.indexOf('ensureBookmarkTracked');
      expect(addAt, greaterThan(0));
      expect(trackAt, greaterThan(addAt));
      expect(method.contains("'/api/interaction'"), isFalse);
      expect(api.contains("postByPath(\n      '/api/v2/bookmarks'"), isTrue);
      expect(api.contains("body: {'newsId': id}"), isTrue);
      expect(api.contains("deleteByPath(\n      '/api/v2/bookmarks/\$id'"), isTrue);
      final v1 = provider.substring(
        provider.indexOf('Future<bool> toggleBookmark(NewsArticle'),
        provider.indexOf('Future<bool> toggleBookmarkV2'),
      );
      expect(v1.contains('addV2Bookmark'), isFalse);
      expect(v1.contains('addBookmark'), isTrue);
    });

    test('refresh keeps an article the list API returned', () {
      final article = _article(articleId);
      final listed = BookmarkListResponse.fromV2Data({
        'items': [
          {'articleId': articleId, '_id': articleId, 'title': 'Article A'},
        ],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      final refreshed = BookmarkRefreshResult.success(listed.data);
      expect(refreshed.phase, BookmarkListPhase.withData);
      expect(refreshed.items.single.newsId, article.newsId);
    });

    test('failed add rollback removes the optimistic article', () {
      final article = _article(articleId);
      final optimistic = BookmarkListEdits.add(const [], article);
      final rolledBack = BookmarkListEdits.remove(optimistic, articleId);
      expect(rolledBack, isEmpty);
    });
  });

  test('Home refresh method is still the single-flight loadInitial wrapper', () {
    final src = File(
      'lib/features/home_v2/presentation/v2_reader_controller.dart',
    ).readAsStringSync();
    final start =
        src.indexOf('Future<void> refresh({bool keepVisible = true}) async {');
    expect(start, greaterThan(0));
    final end = src.indexOf('bool goNext()', start);
    final method = src.substring(start, end);
    expect(method.contains('loadInitial(keepVisible: keepVisible)'), isTrue);
    expect(method.contains('_refreshInFlight'), isTrue);
    expect(method.contains('tryGetV2BookmarkList'), isFalse);
  });
}
