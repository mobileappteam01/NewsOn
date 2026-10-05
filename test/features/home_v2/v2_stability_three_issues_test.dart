import 'dart:io';

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

String _readSrc(String relative) => File(relative).readAsStringSync();

void main() {
  group('Issue1 — no automatic Home refresh on resume/rebuild', () {
    test('V2ReaderHome source no longer auto-refreshes on resume', () {
      final src =
          _readSrc('lib/features/home_v2/presentation/v2_reader_home.dart');
      expect(src.contains('WidgetsBindingObserver'), isFalse);
      expect(src.contains('didChangeAppLifecycleState'), isFalse);
      expect(src.contains('AppLifecycleState.resumed'), isFalse);
      expect(src.contains('refreshHome()'), isTrue);
      expect(src.contains('_onPullToRefresh'), isTrue);
      expect(src.contains('onNewsLanguageChanged'), isTrue);
    });

    test('loaded feed stays identical without an explicit refresh call',
        () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          return V2FeedPage(
            articles: [
              _a('aaaaaaaaaaaaaaaaaaaaaaaa'),
              _a('bbbbbbbbbbbbbbbbbbbbbbbb'),
            ],
            page: page,
            hasMore: false,
          );
        },
      );
      await controller.loadInitial();
      expect(calls, 1);
      final snapshot =
          controller.state.articles.map((e) => e.newsId).toList(growable: false);
      expect(controller.refreshInFlight, isFalse);
      expect(calls, 1);
      expect(controller.state.articles.map((e) => e.newsId).toList(), snapshot);
    });

    test('explicit pull-to-refresh / Home re-tap still fetches', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          return V2FeedPage(
            articles: [
              _a(calls == 1
                  ? 'aaaaaaaaaaaaaaaaaaaaaaaa'
                  : 'cccccccccccccccccccccccc'),
            ],
            page: page,
            hasMore: false,
          );
        },
      );
      await controller.loadInitial();
      await controller.refresh(keepVisible: true);
      expect(calls, 2);
      expect(controller.state.articles.single.newsId, 'cccccccccccccccccccccccc');
    });
  });

  group('Issue3 — preserve feed on transient failure', () {
    test('cold start failure with no cache → error', () async {
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          throw Exception('network_down');
        },
      );
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.error);
      expect(controller.state.articles, isEmpty);
    });

    test('existing feed + refresh failure keeps articles ready', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          throw Exception('HTTP 500');
        },
      );
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.ready);
      await controller.refresh(keepVisible: true);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.single.newsId, 'aaaaaaaaaaaaaaaaaaaaaaaa');
      expect(controller.state.errorMessage, contains('500'));
    });

    test('soft empty response does not wipe existing feed', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          return const V2FeedPage(articles: [], page: 1, hasMore: false);
        },
      );
      await controller.loadInitial();
      await controller.loadInitial(keepVisible: false);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles, isNotEmpty);
    });

    test('explicit refresh empty response replaces feed', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'ta',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          return const V2FeedPage(articles: [], page: 1, hasMore: false);
        },
      );
      await controller.loadInitial();
      await controller.refresh(keepVisible: true);
      expect(controller.state.status, V2ReaderStatus.empty);
      expect(controller.state.articles, isEmpty);
    });

    test('stale generation cannot overwrite newer ready feed', () async {
      var releaseFirst = false;
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          final n = calls;
          if (n == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            while (!releaseFirst) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            return V2FeedPage(
              articles: [_a('oldoldoldoldoldoldoldold')],
              page: 1,
              hasMore: false,
            );
          }
          return V2FeedPage(
            articles: [_a('newnewnewnewnewnewnewnew')],
            page: 1,
            hasMore: false,
          );
        },
      );
      final first = controller.loadInitial();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = controller.refresh(keepVisible: true);
      releaseFirst = true;
      await Future.wait([first, second]);
      expect(controller.state.articles.single.newsId, 'newnewnewnewnewnewnewnew');
    });

    test('malformed item is skipped without failing the feed', () {
      final page = V2FeedItemMapper.parseEnvelope({
        'success': true,
        'data': {
          'items': [
            {
              'articleId': 'goodgoodgoodgoodgoodgood',
              'title': 'Good',
            },
            {
              'title': 'Bad',
            },
            'not-a-map',
            {
              'articleId': 'alsogoodalsogoodalsogood',
              'title': 'Also',
            },
          ],
          'page': 1,
          'hasNextPage': false,
        },
      });
      expect(page.articles.length, 2);
      expect(page.articles.first.newsId, 'goodgoodgoodgoodgoodgood');
    });

    test('refresh failure mid-flight keeps previous feed ready', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          throw Exception('timeout');
        },
      );
      await controller.loadInitial();
      final future = controller.refresh(keepVisible: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.articles, isNotEmpty);
      expect(controller.state.status, isNot(V2ReaderStatus.error));
      await future;
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.single.newsId, 'aaaaaaaaaaaaaaaaaaaaaaaa');
    });
  });

  group('Issue2 — Search bar has no language control', () {
    test('V2SearchTab source has no language control in the search bar', () {
      final src =
          _readSrc('lib/features/search/presentation/v2_search_tab.dart');
      expect(src.contains('LanguageSelectorDialog'), isFalse);
      expect(src.contains('Icons.translate'), isFalse);
      expect(src.contains('newsLanguageName'), isFalse);
      expect(src.contains('language_selector_dialog'), isFalse);
      // Core search affordances remain.
      expect(src.contains('Icons.search_rounded'), isTrue);
      expect(src.contains('Icons.arrow_forward_rounded'), isTrue);
      expect(src.contains('onSubmitted: _submit'), isTrue);
      expect(src.contains('TextInputAction.search'), isTrue);
    });
  });
}
