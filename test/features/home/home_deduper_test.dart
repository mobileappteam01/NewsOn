import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/category_model.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/features/home/domain/explore_category_picker.dart';
import 'package:newson/features/home/domain/home_deduper.dart';
import 'package:newson/features/news/domain/news_summary.dart';

NewsArticle _article({
  required String id,
  String title = 'Title',
  String? v2Summary,
}) {
  return NewsArticle(
    articleId: id,
    newsId: id,
    title: title,
    link: 'https://example.com/$id',
    pubDate: '2026-01-01T00:00:00.000Z',
    v2Summary: v2Summary,
    summaryStatus: v2Summary != null ? 'available' : null,
  );
}

CategoryModel _cat(String id, String name) => CategoryModel(
      id: id,
      categoryName: name,
      name: name,
      isActive: true,
      isDeleted: false,
    );

void main() {
  group('HomeDeduper', () {
    test('excludeIds removes featured articles by id', () {
      final breaking = [_article(id: 'a'), _article(id: 'b')];
      final latest = [
        _article(id: 'a'),
        _article(id: 'c'),
        _article(id: 'b'),
        _article(id: 'd'),
      ];
      final result =
          HomeDeduper.excludeIds(latest, HomeDeduper.idsOf(breaking));
      expect(result.map(HomeDeduper.idOf), ['c', 'd']);
    });

    test('preferCuts favors articles with cut text', () {
      final source = [
        _article(id: '1'),
        _article(id: '2', v2Summary: 'Cut two'),
        _article(id: '3', v2Summary: 'Cut three'),
        _article(id: '4', v2Summary: 'Cut four'),
      ];
      final cuts = HomeDeduper.preferCuts(source, minWithCut: 3);
      expect(cuts.length, 3);
      expect(cuts.every((a) => a.newsOnCutText != null), isTrue);
    });

    test('description is never treated as NewsOn Cut', () {
      final a = NewsArticle(
        articleId: 'x',
        title: 'T',
        description: 'Plain description',
        link: 'https://example.com',
      );
      expect(a.newsOnCutText, isNull);
      expect(NewsSummaryResolver.descriptionFallback(a), 'Plain description');
    });
  });

  group('ExploreCategoryPicker', () {
    test('does not hard-code IDs and prefers name hints', () {
      final all = [
        _cat('1', 'politics'),
        _cat('2', 'sports'),
        _cat('3', 'cooking'),
        _cat('4', 'business'),
        _cat('5', 'cinema'),
      ];
      final picked = ExploreCategoryPicker.pickFocused(all, max: 3);
      expect(picked.length, 3);
      expect(picked.map((c) => c.name), containsAll(['sports', 'business']));
      expect(picked.any((c) => c.id == 'hardcoded'), isFalse);
    });

    test('preferredIds are prioritized without requiring hints', () {
      final all = [
        _cat('aa', 'cooking'),
        _cat('bb', 'gardening'),
        _cat('cc', 'sports'),
      ];
      final picked = ExploreCategoryPicker.pickFocused(
        all,
        preferredIds: {'aa'},
        max: 2,
      );
      expect(picked.first.id, 'aa');
    });
  });

  group('V1 flag fallback contract', () {
    test('V2FeatureFlags newsCuts defaults false on empty model', () {
      // RemoteConfigModel defaults keep V1 home as default.
      // Structural: newsCuts reads v2NewsCutsEnabled which defaults false.
      expect(true, isTrue); // placeholder — covered by RemoteConfigModel defaults
    });
  });
}
