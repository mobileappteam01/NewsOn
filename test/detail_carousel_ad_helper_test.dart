import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/utils/detail_carousel_ad_helper.dart';
import 'package:newson/data/models/ad_policy.dart';

void main() {
  group('DetailCarouselAdHelper.buildPagesWithConfig', () {
    test('no ads when disabled', () {
      final pages = DetailCarouselAdHelper.buildPagesWithConfig(
        articleCount: 10,
        enabled: false,
        interval: 4,
      );
      expect(pages.length, 10);
      expect(pages.every((p) => p is DetailArticlePageItem), isTrue);
    });

    test('inserts ad after every 4 articles, never first/last', () {
      final pages = DetailCarouselAdHelper.buildPagesWithConfig(
        articleCount: 9,
        enabled: true,
        interval: 4,
      );
      // A A A A Ad A A A A  → 10 pages (2 ads?  after 4 and after 8)
      // indices: 0,1,2,3 article; 4 ad; 5,6,7,8 article; — after 8 is last article index 8, (8+1)%4==0 but i==last so no ad
      // articles 0-3, ad, 4-7, ad? (i=7 is article index 7, i+1=8 %4==0, not last) yes ad, then article 8
      // 9 articles: ads after index 3 and 7 → 11 pages
      expect(pages.length, 11);
      expect(pages[4], isA<DetailAdPageItem>());
      expect(pages[9], isA<DetailAdPageItem>());
      expect(pages.first, isA<DetailArticlePageItem>());
      expect(pages.last, isA<DetailArticlePageItem>());
    });

    test('article ↔ carousel index round-trip with ads', () {
      final pages = DetailCarouselAdHelper.buildPagesWithConfig(
        articleCount: 9,
        enabled: true,
        interval: 4,
      );
      for (var a = 0; a < 9; a++) {
        final c = DetailCarouselAdHelper.carouselIndexForArticle(pages, a);
        expect(
          DetailCarouselAdHelper.articleIndexForCarousel(pages, c),
          a,
        );
      }
      expect(DetailCarouselAdHelper.isAdPage(pages, 4), isTrue);
      expect(DetailCarouselAdHelper.articleIndexForCarousel(pages, 4), isNull);
    });
  });

  group('AdPolicy detail carousel defaults', () {
    test('defaults enable carousel ads every 4 articles', () {
      const policy = AdPolicy.defaults;
      expect(policy.detailCarouselAdsEnabled, isTrue);
      expect(policy.detailCarouselAdInterval, 4);
      expect(policy.interstitialEnabled, isFalse);
    });

    test('parses Firebase keys and clamps interval', () {
      final policy = AdPolicy.fromMap({
        'detail_carousel_ads_enabled': true,
        'detail_carousel_ad_interval': 99,
      });
      expect(policy.detailCarouselAdsEnabled, isTrue);
      expect(policy.detailCarouselAdInterval, 8);
    });
  });
}
