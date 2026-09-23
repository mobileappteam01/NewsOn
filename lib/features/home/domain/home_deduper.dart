import '../../../data/models/news_article.dart';
import '../../news/domain/news_summary.dart';

/// ID-based duplicate control across Home sections.
///
/// Uses [NewsArticle.analyticsNewsId] primarily. No fuzzy matching.
abstract final class HomeDeduper {
  static String idOf(NewsArticle a) {
    final id = a.analyticsNewsId.trim();
    if (id.isNotEmpty) return id;
    return a.articleId?.trim() ?? a.title;
  }

  /// Returns [candidates] excluding IDs already present in [exclude].
  static List<NewsArticle> excludeIds(
    List<NewsArticle> candidates,
    Set<String> exclude,
  ) {
    if (exclude.isEmpty) return List<NewsArticle>.from(candidates);
    return candidates
        .where((a) => !exclude.contains(idOf(a)))
        .toList(growable: false);
  }

  static Set<String> idsOf(Iterable<NewsArticle> articles) {
    return articles.map(idOf).where((id) => id.isNotEmpty).toSet();
  }

  /// Prefer articles with a real NewsOn Cut text for the Cuts rail.
  static List<NewsArticle> preferCuts(
    List<NewsArticle> source, {
    int minWithCut = 3,
    int max = 12,
  }) {
    final withCut =
        source.where((a) => a.newsOnCutText != null).take(max).toList();
    if (withCut.length >= minWithCut) return withCut;
    return source.take(max).toList(growable: false);
  }
}
