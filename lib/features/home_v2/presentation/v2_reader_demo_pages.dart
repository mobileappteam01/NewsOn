import '../../../data/models/news_article.dart';

/// Temporary in-memory expansion so page-turn can be exercised when the
/// backend returns fewer than 3 articles. Never persists; never invents IDs.
List<NewsArticle> expandV2ReaderDemoPages(List<NewsArticle> source) {
  if (source.length >= 3) return List<NewsArticle>.unmodifiable(source);
  if (source.isEmpty) return const [];
  if (source.length == 1) {
    final a = source.first;
    return List<NewsArticle>.unmodifiable([a, a, a]);
  }
  // Exactly two articles → A, B, A
  return List<NewsArticle>.unmodifiable([source[0], source[1], source[0]]);
}
