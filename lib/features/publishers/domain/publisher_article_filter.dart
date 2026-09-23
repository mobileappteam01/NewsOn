import '../../../data/models/news_article.dart';
import '../../news/domain/news_summary.dart';
import 'publisher_model.dart';

/// Filter helpers for publisher article lists (client-side fallback).
abstract final class PublisherArticleFilter {
  static bool matchesPublisher(NewsArticle article, PublisherModel publisher) {
    final pid = article.publisherId?.trim().toLowerCase();
    if (pid != null &&
        pid.isNotEmpty &&
        (pid == publisher.id.toLowerCase() ||
            pid == (publisher.slug?.toLowerCase() ?? ''))) {
      return true;
    }

    final srcId = article.sourceId?.trim().toLowerCase();
    final pubSrcId = publisher.sourceId?.trim().toLowerCase();
    if (srcId != null &&
        srcId.isNotEmpty &&
        pubSrcId != null &&
        pubSrcId.isNotEmpty &&
        srcId == pubSrcId) {
      return true;
    }

    final aName = (article.sourceName ?? article.publisherDisplayName)
        .trim()
        .toLowerCase();
    final pName = (publisher.sourceName ?? publisher.name).trim().toLowerCase();
    if (aName.isEmpty || pName.isEmpty) return false;
    return aName == pName;
  }

  static List<NewsArticle> apply(
    Iterable<NewsArticle> articles,
    PublisherModel publisher, {
    Set<String> excludeIds = const {},
  }) {
    final seen = <String>{...excludeIds};
    final out = <NewsArticle>[];
    for (final a in articles) {
      if (!matchesPublisher(a, publisher)) continue;
      final id = a.analyticsNewsId;
      if (seen.contains(id)) continue;
      seen.add(id);
      out.add(a);
    }
    return out;
  }
}
