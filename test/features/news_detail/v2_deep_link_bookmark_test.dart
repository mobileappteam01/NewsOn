import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';
import 'package:newson/data/services/deep_link_service.dart';

void main() {
  setUp(() {
    DeepLinkService.instance.debugReset();
  });

  group('V2 deep link routing contracts', () {
    test('V2 deep link never references NewsArticleResolver in open path', () {
      final src = File(
        'lib/data/services/deep_link_service.dart',
      ).readAsStringSync();
      // V2 path opens V2ArticleDetailScreen directly.
      expect(src.contains('V2ArticleDetailScreen'), isTrue);
      expect(src.contains('_tryOpenPendingV2'), isTrue);
      expect(src.contains('parseV2ArticleId'), isTrue);
      // Resolver remains for V1 only.
      expect(src.contains('NewsArticleResolver'), isTrue);
      expect(
        src.contains('Opening V2 article detail'),
        isTrue,
      );
      expect(src.contains('getNewsByIdMobile'), isFalse);
    });

    test('enqueue V2 URI sets pending V2 id and skips V1 id', () {
      final svc = DeepLinkService.instance;
      final uri = DeepLinkConstants.buildV2HttpsDeepLink(
        '6ab1d4fda5abc256076d157e',
      );
      svc.debugEnqueueUri(uri);
      expect(svc.pendingArticleId, '6ab1d4fda5abc256076d157e');
      expect(svc.debugPendingLinkKey, 'v2:6ab1d4fda5abc256076d157e');
    });

    test('duplicate warm V2 URI after open is ignored', () {
      final svc = DeepLinkService.instance;
      final uri = DeepLinkConstants.buildV2HttpsDeepLink(
        '6ab1d4fda5abc256076d157e',
      );
      svc.debugEnqueueUri(uri, coldStart: true);
      expect(svc.hasPendingArticle, isTrue);
      final key = svc.debugPendingLinkKey!;
      svc.debugMarkOpened(key);
      svc.debugClearPendingOnly();
      expect(svc.hasPendingArticle, isFalse);

      svc.debugEnqueueUri(uri); // warm redelivery
      expect(svc.hasPendingArticle, isFalse);
      expect(svc.debugLastOpenedLinkKey, key);
    });

    test('identical warm redelivery ignored when lastOpened matches', () {
      final svc = DeepLinkService.instance;
      final uri = DeepLinkConstants.buildV2HttpsDeepLink(
        'aaaaaaaaaaaaaaaaaaaaaaaa',
      );
      svc.debugEnqueueUri(uri, coldStart: true);
      final openedKey = svc.debugPendingLinkKey!;
      svc.debugMarkOpened(openedKey);
      svc.debugClearPendingOnly();

      expect(svc.hasPendingArticle, isFalse);
      expect(svc.debugLastOpenedLinkKey, openedKey);

      svc.debugEnqueueUri(uri); // warm duplicate
      expect(svc.hasPendingArticle, isFalse);
    });

    test('V1 deep link enqueue still uses v1 key', () {
      final svc = DeepLinkService.instance;
      final uri = Uri.parse(
        'https://api.newson.app/news/709cfe94f5f24201ffd04d0610bcd2dd',
      );
      svc.debugEnqueueUri(uri);
      expect(svc.pendingArticleId, '709cfe94f5f24201ffd04d0610bcd2dd');
      expect(
        svc.debugPendingLinkKey,
        'v1:709cfe94f5f24201ffd04d0610bcd2dd',
      );
      expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isFalse);
    });
  });

  group('V2 bookmark / share source contracts', () {
    test('V2 detail bookmark uses toggleBookmarkV2 not V1 addBookmark', () {
      final src = File(
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('toggleBookmarkV2'), isTrue);
      expect(src.contains('.toggleBookmark('), isFalse);
      expect(src.contains('BookmarkApiService'), isFalse);
      expect(src.contains('shareArticle'), isTrue);
      expect(src.contains('v2: true'), isTrue);
    });

    test('V2 reader bookmark/share use V2 paths', () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(src.contains('toggleBookmarkV2'), isTrue);
      expect(src.contains('v2: true'), isTrue);
    });

    test('V2 For You / Search / Home / Publisher use toggleBookmarkV2', () {
      const paths = [
        'lib/features/for_you/presentation/v2_for_you_tab.dart',
        'lib/features/search/presentation/v2_search_tab.dart',
        'lib/features/home/presentation/v2_home_screen.dart',
        'lib/features/publishers/presentation/publisher_page.dart',
      ];
      for (final path in paths) {
        final src = File(path).readAsStringSync();
        expect(src.contains('toggleBookmarkV2'), isTrue, reason: path);
        expect(src.contains('.toggleBookmark('), isFalse, reason: path);
      }
    });

    test('toggleBookmarkV2 never calls BookmarkApiService', () {
      final src = File(
        'lib/providers/bookmark_provider.dart',
      ).readAsStringSync();
      final start = src.indexOf('Future<bool> toggleBookmarkV2');
      expect(start, greaterThan(0));
      final end = src.indexOf('\n  // ignore: unused_element', start);
      final end2 = src.indexOf('\n  Future<void> removeBookmark', start);
      final cut = end > start
          ? end
          : (end2 > start ? end2 : src.length);
      final method = src.substring(start, cut);
      expect(method.contains('_requireBookmarkApi'), isFalse);
      expect(method.contains('ensureBookmarkTracked'), isTrue);
      expect(method.contains('InteractionService'), isTrue);
      expect(method.contains('api.newson.app'), isFalse);
    });
  });
}
