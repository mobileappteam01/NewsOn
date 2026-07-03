import '../../data/models/news_article.dart';

/// One visual segment of the For You feed: mosaic hero + spotlight grid items.
class ForYouFeedBlock {
  const ForYouFeedBlock({
    required this.index,
    required this.mosaic,
    required this.spotlight,
  });

  final int index;
  final List<NewsArticle> mosaic;
  final List<NewsArticle> spotlight;

  bool get showMosaic => mosaic.length >= 2;
}

/// Splits the feed into repeating spotlight blocks for scroll/load-more.
class ForYouFeedLayout {
  ForYouFeedLayout._();

  /// Articles per block: up to 3 in mosaic, remainder in 2-column spotlight grid.
  static const int blockSize = 6;

  static bool hasHeroImage(NewsArticle article) {
    final url = article.imageUrl ?? article.sourceIcon;
    return url != null && url.trim().isNotEmpty;
  }

  static String articleKey(NewsArticle article) {
    return article.newsId ?? article.articleId ?? article.title;
  }

  static List<ForYouFeedBlock> partition(List<NewsArticle> articles) {
    if (articles.isEmpty) return const [];

    final blocks = <ForYouFeedBlock>[];
    for (var start = 0; start < articles.length; start += blockSize) {
      final end = (start + blockSize).clamp(0, articles.length);
      final chunk = articles.sublist(start, end);
      final mosaic = pickMosaicArticles(chunk, blocks.length);
      final mosaicKeys = mosaic.map(articleKey).toSet();
      final spotlight = chunk
          .where((a) => !mosaicKeys.contains(articleKey(a)))
          .toList();
      blocks.add(
        ForYouFeedBlock(
          index: blocks.length,
          mosaic: mosaic,
          spotlight: spotlight,
        ),
      );
    }
    return blocks;
  }

  /// Picks up to 3 image articles; [blockIndex] rotates picks for variety.
  static List<NewsArticle> pickMosaicArticles(
    List<NewsArticle> chunk,
    int blockIndex,
  ) {
    final withImages = chunk.where(hasHeroImage).toList();
    if (withImages.isEmpty) return const [];
    if (withImages.length == 1) return withImages;

    final offset = blockIndex % withImages.length;
    final ordered = [
      ...withImages.sublist(offset),
      ...withImages.sublist(0, offset),
    ];
    return ordered.take(3).toList();
  }

  static int feedIndexOf(List<NewsArticle> all, NewsArticle article) {
    final key = articleKey(article);
    return all.indexWhere((a) => articleKey(a) == key);
  }
}
