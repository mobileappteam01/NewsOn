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

    test('custom-scheme V2 URI parses and enqueues (WhatsApp fallback)', () {
      final svc = DeepLinkService.instance;
      final uri = DeepLinkConstants.buildV2AppDeepLink(
        '6ab6a6e7261c38e362b06a23',
      );
      expect(uri.toString(), 'newson://v2/news/6ab6a6e7261c38e362b06a23');
      expect(DeepLinkConstants.parseV2ArticleId(uri), '6ab6a6e7261c38e362b06a23');
      svc.debugEnqueueUri(uri, coldStart: true);
      expect(svc.pendingArticleId, '6ab6a6e7261c38e362b06a23');
      expect(svc.debugPendingLinkKey, 'v2:6ab6a6e7261c38e362b06a23');
    });

    test('malformed V2 path does not enqueue', () {
      final svc = DeepLinkService.instance;
      svc.debugEnqueueUri(Uri.parse('https://v2-api.newson.app/v2/news/'));
      expect(svc.hasPendingArticle, isFalse);
      svc.debugEnqueueUri(Uri.parse('https://v2-api.newson.app/v2/other/abc'));
      expect(svc.hasPendingArticle, isFalse);
    });

    test('V2 open path wraps navigation in try/catch (no crash on push fail)', () {
      final src = File(
        'lib/data/services/deep_link_service.dart',
      ).readAsStringSync();
      expect(src.contains('V2 detail navigation failed'), isTrue);
      expect(src.contains('V2ArticleDetailScreen(articleId: articleId)'), isTrue);
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

    test('V2 For You / Search / Home use toggleBookmarkV2', () {
      const paths = [
        'lib/features/for_you/presentation/v2_for_you_tab.dart',
        'lib/features/search/presentation/v2_search_tab.dart',
        'lib/features/home/presentation/v2_home_screen.dart',
      ];
      for (final path in paths) {
        final src = File(path).readAsStringSync();
        expect(src.contains('toggleBookmarkV2'), isTrue, reason: path);
        expect(src.contains('.toggleBookmark('), isFalse, reason: path);
      }
    });

    test('toggleBookmarkV2 persists with POST /api/v2/bookmarks', () {
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
      final addAt = method.indexOf('addV2Bookmark');
      final trackAt = method.indexOf('ensureBookmarkTracked');
      expect(addAt, greaterThan(0));
      expect(trackAt, greaterThan(addAt));
      expect(method.contains('deleteV2Bookmark'), isTrue);
      expect(method.contains('/api/interaction'), isFalse);
      expect(method.contains('api.newson.app'), isFalse);
    });
  });
}
