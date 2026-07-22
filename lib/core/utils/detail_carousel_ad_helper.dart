import '../../data/models/ad_policy.dart';
import '../../data/services/ad_service.dart';

/// One page in the news-detail vertical/horizontal carousel.
sealed class DetailCarouselItem {
  const DetailCarouselItem();
}

class DetailArticlePageItem extends DetailCarouselItem {
  const DetailArticlePageItem(this.articleIndex);
  final int articleIndex;
}

class DetailAdPageItem extends DetailCarouselItem {
  const DetailAdPageItem(this.adSlotIndex);
  final int adSlotIndex;
}

/// Builds Inshorts-style article/ad page sequences for [NewsDetailScreen].
///
/// Ads are inserted after every [AdPolicy.detailCarouselAdInterval] articles
/// (never as the first or last page). Mapping helpers keep audio sync and
/// analytics on pure article indices.
class DetailCarouselAdHelper {
  DetailCarouselAdHelper._();

  static bool get enabled {
    final policy = AdService().policy;
    return policy.enabled && policy.detailCarouselAdsEnabled;
  }

  static int get interval {
    final policy = AdService().policy;
    return policy.detailCarouselAdInterval.clamp(3, 8);
  }

  static bool shouldShow(AdPolicy policy) =>
      policy.enabled && policy.detailCarouselAdsEnabled;

  /// Interleave articles with ad pages. Example interval=4:
  /// A A A A · Ad · A A A A · Ad · A …
  static List<DetailCarouselItem> buildPages(int articleCount) {
    return buildPagesWithConfig(
      articleCount: articleCount,
      enabled: enabled,
      interval: interval,
    );
  }

  /// Pure builder for tests and [buildPages].
  static List<DetailCarouselItem> buildPagesWithConfig({
    required int articleCount,
    required bool enabled,
    required int interval,
  }) {
    if (articleCount <= 0) return const [];
    final gap = interval.clamp(3, 8);
    if (!enabled || articleCount < gap + 1) {
      return List.generate(
        articleCount,
        (i) => DetailArticlePageItem(i),
      );
    }

    final pages = <DetailCarouselItem>[];
    var adSlot = 0;
    for (var i = 0; i < articleCount; i++) {
      pages.add(DetailArticlePageItem(i));
      final isBoundary = (i + 1) % gap == 0;
      final notLast = i < articleCount - 1;
      if (isBoundary && notLast) {
        pages.add(DetailAdPageItem(adSlot++));
      }
    }
    return pages;
  }

  static int carouselIndexForArticle(
    List<DetailCarouselItem> pages,
    int articleIndex,
  ) {
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (page is DetailArticlePageItem && page.articleIndex == articleIndex) {
        return i;
      }
    }
    return 0;
  }

  static int? articleIndexForCarousel(
    List<DetailCarouselItem> pages,
    int carouselIndex,
  ) {
    if (carouselIndex < 0 || carouselIndex >= pages.length) return null;
    final page = pages[carouselIndex];
    if (page is DetailArticlePageItem) return page.articleIndex;
    return null;
  }

  static bool isAdPage(List<DetailCarouselItem> pages, int carouselIndex) {
    if (carouselIndex < 0 || carouselIndex >= pages.length) return false;
    return pages[carouselIndex] is DetailAdPageItem;
  }
}
