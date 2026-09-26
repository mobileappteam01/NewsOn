/// Display pages for the V2 reader. Ads are their own pages.
///
/// Article indexes stay on the news list. Ad pages do not increment them.
sealed class V2ReaderDisplayPage {
  const V2ReaderDisplayPage();
}

class V2ReaderArticleDisplay extends V2ReaderDisplayPage {
  const V2ReaderArticleDisplay(this.articleIndex);
  final int articleIndex;
}

class V2ReaderAdDisplay extends V2ReaderDisplayPage {
  const V2ReaderAdDisplay(this.slotIndex);
  final int slotIndex;
}

/// 4 article pages, then 1 ad page, repeating.
abstract final class V2ReaderDisplayPages {
  static const int articlesPerAd = 4;

  static List<V2ReaderDisplayPage> build(
    int articleCount, {
    bool adsEnabled = true,
    int articlesPerAd = V2ReaderDisplayPages.articlesPerAd,
  }) {
    if (articleCount <= 0) return const [];
    final pages = <V2ReaderDisplayPage>[];
    var slot = 0;
    for (var i = 0; i < articleCount; i++) {
      pages.add(V2ReaderArticleDisplay(i));
      final insertAd = adsEnabled &&
          articlesPerAd > 0 &&
          (i + 1) % articlesPerAd == 0;
      if (insertAd) {
        pages.add(V2ReaderAdDisplay(slot));
        slot++;
      }
    }
    return pages;
  }

  static int? articleIndexAt(List<V2ReaderDisplayPage> pages, int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return null;
    final page = pages[pageIndex];
    if (page is V2ReaderArticleDisplay) return page.articleIndex;
    return null;
  }
}
