import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-contract regression: current V2 surfaces must use
/// [BookmarkProvider.toggleBookmarkV2] → InteractionService → POST /api/interaction
/// and must never call V1 `/api/bookmark/*` via [toggleBookmark].
void main() {
  const v2Surfaces = <String, String>{
    'V2 For You': 'lib/features/for_you/presentation/v2_for_you_tab.dart',
    'V2 Search': 'lib/features/search/presentation/v2_search_tab.dart',
    'V2 Home': 'lib/features/home/presentation/v2_home_screen.dart',
    'V2 Publisher': 'lib/features/publishers/presentation/publisher_page.dart',
    'V2 Reader': 'lib/features/home_v2/presentation/v2_reader_home.dart',
    'V2 Article Detail':
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
  };

  group('V2 surface bookmark contracts', () {
    for (final entry in v2Surfaces.entries) {
      test('${entry.key} uses toggleBookmarkV2, not V1 toggleBookmark', () {
        final src = File(entry.value).readAsStringSync();
        expect(src.contains('toggleBookmarkV2'), isTrue);
        // Exact V1 call site — allow the V2 method name only.
        expect(src.contains('.toggleBookmark('), isFalse);
        expect(src.contains('BookmarkApiService'), isFalse);
        expect(src.contains('/api/bookmark'), isFalse);
        expect(src.contains('addBookmark'), isFalse);
        expect(src.contains('trackBookmark'), isFalse);
      });
    }

    test('no current V2 surface calls /api/bookmark/*', () {
      for (final path in v2Surfaces.values) {
        final src = File(path).readAsStringSync();
        expect(src.contains('/api/bookmark'), isFalse, reason: path);
        expect(src.contains('BookmarkApiService'), isFalse, reason: path);
      }
    });

    test('V1 toggleBookmark still uses BookmarkApiService', () {
      final src =
          File('lib/providers/bookmark_provider.dart').readAsStringSync();
      final start = src.indexOf('Future<bool> toggleBookmark(NewsArticle');
      expect(start, greaterThan(0));
      // Cut before the V2 doc comment that mentions ensureBookmarkTracked.
      final v2Doc = src.indexOf('/// Persists engagement via', start);
      final v2Start = src.indexOf('Future<bool> toggleBookmarkV2', start);
      final cut = v2Doc > start ? v2Doc : v2Start;
      expect(cut, greaterThan(start));
      final v1Method = src.substring(start, cut);
      expect(v1Method.contains('_requireBookmarkApi'), isTrue);
      expect(v1Method.contains('addBookmark'), isTrue);
      expect(v1Method.contains('removeBookmark'), isTrue);
      expect(v1Method.contains('ensureBookmarkTracked'), isFalse);
    });

    test('V2 Article Detail bookmark path unchanged (toggleBookmarkV2)', () {
      final src = File(
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('toggleBookmarkV2'), isTrue);
      expect(src.contains('.toggleBookmark('), isFalse);
      expect(src.contains('V2ArticleDetailApi'), isTrue);
    });
  });
}
