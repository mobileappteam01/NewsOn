import '../../../data/models/news_article.dart';

/// Explicit summary product states for NewsOn Cuts.
enum NewsSummaryStatus {
  unavailable,
  pending,
  available,
  failed,
}

/// Resolves displayable NewsOn Cut text without fabricating summaries.
class NewsSummaryResolver {
  const NewsSummaryResolver._();

  static NewsSummaryStatus statusOf(NewsArticle article) {
    final raw = (article.summaryStatus ?? '').trim().toLowerCase();
    switch (raw) {
      case 'pending':
      case 'processing':
      case 'generating':
        return NewsSummaryStatus.pending;
      case 'failed':
      case 'error':
        return NewsSummaryStatus.failed;
      case 'available':
      case 'ready':
      case 'ok':
        return _hasCutText(article)
            ? NewsSummaryStatus.available
            : NewsSummaryStatus.unavailable;
      case 'unavailable':
      case 'none':
        return NewsSummaryStatus.unavailable;
      default:
        if (_hasCutText(article)) return NewsSummaryStatus.available;
        return NewsSummaryStatus.unavailable;
    }
  }

  /// Fallback hierarchy:
  /// 1) v2Summary  2) legacy aiSummary  3) null (never label description as AI)
  static String? cutText(NewsArticle article) {
    final v2 = article.v2Summary?.trim();
    if (v2 != null && v2.isNotEmpty) return v2;

    final legacy = article.aiSummary?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;

    return null;
  }

  /// Description may be shown as ordinary excerpt, never branded as NewsOn Cut.
  static String? descriptionFallback(NewsArticle article) {
    final d = article.description?.trim();
    if (d == null || d.isEmpty) return null;
    return d;
  }

  static bool _hasCutText(NewsArticle article) => cutText(article) != null;
}

extension NewsArticleSummaryX on NewsArticle {
  NewsSummaryStatus get resolvedSummaryStatus =>
      NewsSummaryResolver.statusOf(this);

  String? get newsOnCutText => NewsSummaryResolver.cutText(this);

  String? get canonicalArticleUrl {
    final candidates = [link, sourceUrl];
    for (final c in candidates) {
      final t = c?.trim();
      if (t == null || t.isEmpty) continue;
      if (t.startsWith('http://') || t.startsWith('https://')) return t;
      return 'https://$t';
    }
    return null;
  }

  String get publisherDisplayName {
    final name = sourceName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        !isIngestionProviderLabel(name)) {
      return name;
    }
    final id = sourceId?.trim();
    if (id != null &&
        id.isNotEmpty &&
        !isIngestionProviderLabel(id)) {
      return id;
    }
    // Never surface ingestion-provider labels as the brand.
    return 'Publisher';
  }

  /// Ingestion/adapter labels that must not appear as publisher brands.
  static bool isIngestionProviderLabel(String? name) {
    final n = name?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return true;
    return n == 'newsdata aggregator' ||
        n == 'newsdata' ||
        n == 'newsdata.io' ||
        n == 'generic_rss' ||
        n == 'generic rss' ||
        n == 'aggregator' ||
        n == 'rss aggregator';
  }

  String get analyticsNewsId {
    final id = (newsId ?? articleId)?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '';
  }

  /// ObjectId for analytics track — never send titles (backend rejects → 400).
  String? get analyticsTrackNewsId {
    final id = analyticsNewsId;
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id)) return id;
    return null;
  }

  /// Stable key for opening Publisher pages (id preferred, else name).
  String get publisherRouteKey {
    final pid = publisherId?.trim();
    if (pid != null && pid.isNotEmpty) return pid;
    final sid = sourceId?.trim();
    if (sid != null && sid.isNotEmpty) return sid;
    return publisherDisplayName;
  }
}
