import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home_v2/data/v2_home_api.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _a(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

void main() {
  group('V2ReaderController transient refresh resilience', () {
    test('429/transient failure keeps existing feed visible', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'english',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('a1'), _a('a2')],
              page: 1,
              hasMore: false,
            );
          }
          throw V2HomeException(
            'Too many requests. Please try again later.',
            statusCode: 429,
            kind: V2HomeFailureKind.rateLimited,
          );
        },
      );

      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.length, 2);

      await controller.refresh(keepVisible: true);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.length, 2);
      expect(controller.state.errorMessage, isNull);
    });

    test('empty refresh does not wipe existing feed', () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'english',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_a('a1')],
              page: 1,
              hasMore: false,
            );
          }
          return const V2FeedPage(articles: [], page: 1, hasMore: false);
        },
      );

      await controller.loadInitial();
      expect(controller.state.articles.length, 1);

      await controller.refresh(keepVisible: true);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.length, 1);
    });

    test('stale queued refresh cannot blank a successful feed', () async {
      final controller = V2ReaderController(
        newsLanguageCode: () => 'english',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          return V2FeedPage(
            articles: [_a('fresh')],
            page: 1,
            hasMore: false,
          );
        },
      );

      await controller.loadInitial();
      expect(controller.state.articles.first.newsId, 'fresh');

      final first = controller.refresh(keepVisible: true);
      final second = controller.refresh(keepVisible: true);
      await Future.wait([first, second]);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles, isNotEmpty);
    });
  });

  group('V2HomeApi failure classification', () {
    test('maps 429 to rateLimited transient', () {
      final ex = V2HomeException(
        'Too many requests',
        statusCode: 429,
        kind: V2HomeFailureKind.rateLimited,
      );
      expect(ex.isTransient, isTrue);
    });
  });
}
