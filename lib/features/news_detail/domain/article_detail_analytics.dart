import '../../../data/models/news_article.dart';
import '../../news/domain/news_summary.dart';

/// Pure helpers for V2 article-detail analytics decisions (unit-testable).
abstract final class ArticleDetailAnalytics {
  /// Whether [summary_view] should fire for this visibility pass.
  static bool shouldTrackSummaryView({
    required NewsArticle article,
    required bool alreadyTracked,
  }) {
    if (alreadyTracked) return false;
    return article.resolvedSummaryStatus == NewsSummaryStatus.available;
  }

  /// Safe metadata for full-article CTA (never includes tokens/PII).
  static Map<String, String> fullArticleParams({
    required NewsArticle article,
    required String url,
  }) {
    return {
      'newsId': article.analyticsNewsId,
      'url': url,
    };
  }

  static Map<String, String> newsOpenParams(NewsArticle article) => {
        'newsId': article.analyticsNewsId,
      };

  static Map<String, String> bookmarkParams(NewsArticle article) => {
        'newsId': article.analyticsNewsId,
      };

  static Map<String, String> shareParams(NewsArticle article) => {
        'newsId': article.analyticsNewsId,
      };
}
