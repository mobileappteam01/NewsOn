import '../../../data/models/news_article.dart';
import '../domain/news_summary.dart';

/// Maps Phase 6 V2 feed items (`/api/v2/search`, `/api/v2/for-you`) into
/// [NewsArticle] without dropping V2 fields.
///
/// Backend item shape (conceptual):
/// `{ articleId, title, image, publisher:{id,name}, category:[{id,name}],
///   publishedAt, v2Summary, canonicalUrl, language, link, isBookmarked? }`
abstract final class V2FeedItemMapper {
  static NewsArticle? fromItem(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    final articleId = _str(
      map['articleId'] ?? map['article_id'] ?? map['_id'] ?? map['newsId'],
    );
    if (articleId == null || articleId.isEmpty) return null;

    final publisher = map['publisher'];
    String? publisherId;
    String? publisherNestedName;
    if (publisher is Map) {
      publisherId =
          _str(publisher['id'] ?? publisher['_id'] ?? publisher['publisherId']);
      publisherNestedName = _str(
        publisher['name'] ??
            publisher['source_name'] ??
            publisher['displayName'] ??
            publisher['attributionName'],
      );
    } else if (publisher is String) {
      publisherNestedName = publisher.trim().isEmpty ? null : publisher.trim();
    }

    final categories = <String>[];
    final catRaw = map['category'] ?? map['categories'];
    if (catRaw is List) {
      for (final c in catRaw) {
        if (c is Map) {
          final name = _str(c['name'] ?? c['categoryName']);
          if (name != null) categories.add(name);
        } else {
          final s = _str(c);
          if (s != null) categories.add(s);
        }
      }
    }

    final image = _str(map['image'] ?? map['image_url'] ?? map['imageUrl']);
    final link = _str(
      map['link'] ?? map['canonicalUrl'] ?? map['canonical_url'] ?? map['url'],
    );
    final publishedAt = _str(
      map['publishedAt'] ?? map['pubDate'] ?? map['published_at'],
    );
    final v2Summary = _str(
      map['v2Summary'] ?? map['v2_summary'] ?? map['newson_cut'],
    );
    // Full article body from V2/NewsData ingestion (not the ~60-word Cut).
    final content = _str(
      map['content'] ??
          map['fullContent'] ??
          map['full_content'] ??
          map['articleContent'] ??
          map['article_content'] ??
          map['body'],
    );
    final description = _str(
      map['description'] ??
          map['snippet'] ??
          map['excerpt'] ??
          map['description_text'],
    );

    // Prefer the original publisher/source brand over ingestion-provider
    // labels such as "NewsData Aggregator" that some V2 adapters emit as
    // publisher.name.
    final source = map['source'];
    String? nestedSourceName;
    if (source is Map) {
      nestedSourceName = _str(source['name'] ?? source['source_name']);
    } else if (source is String) {
      nestedSourceName = _str(source);
    }

    final displayPublisher = resolveOriginalPublisherName(
      sourceName: _str(map['source_name'] ?? map['sourceName']),
      nestedSourceName: nestedSourceName,
      originalPublisher: _str(
        map['originalPublisher'] ??
            map['original_publisher'] ??
            map['originalSource'] ??
            map['original_source'],
      ),
      attributionName: _str(map['attributionName'] ?? map['attribution_name']),
      publisherName: publisherNestedName,
      sourceId: _str(map['source_id'] ?? map['sourceId']),
    );

    // Adapt into the fields [NewsArticle.fromJson] already understands.
    return NewsArticle.fromJson({
      '_id': articleId,
      'article_id': map['article_id'] ?? articleId,
      'title': map['title'] ?? 'No Title',
      'link': link,
      'image_url': image,
      'pubDate': publishedAt,
      'language': map['language'],
      'description': description,
      'content': content,
      'v2_summary': v2Summary,
      'summary_status': map['summary_status'] ??
          map['summaryStatus'] ??
          map['summarySource'],
      'ai_summary': map['ai_summary'] ?? map['aiSummary'],
      'source_name': displayPublisher,
      'source_id': map['source_id'] ?? map['sourceId'],
      'source_url':
          map['source_url'] ?? map['canonicalUrl'] ?? map['canonical_url'],
      'source_icon': map['source_icon'] ?? map['sourceIcon'],
      'publisher_id': publisherId ?? map['publisherId'] ?? map['publisher_id'],
      'category': categories.isEmpty ? map['category'] : categories,
      'isBookmarked': map['isBookmarked'] == true || map['is_bookmarked'] == true,
    });
  }

  static List<NewsArticle> fromItems(dynamic items) {
    if (items is! List) return const [];
    final out = <NewsArticle>[];
    final seen = <String>{};
    for (final item in items) {
      final article = fromItem(item);
      if (article == null) continue;
      final id = article.newsId ?? article.articleId;
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(article);
    }
    return out;
  }

  /// Unwraps `{ success, data: { items, page, limit, hasNextPage, mode? } }`.
  static V2FeedPage parseEnvelope(dynamic responseData) {
    Map<String, dynamic>? root;
    if (responseData is Map<String, dynamic>) {
      root = responseData;
    } else if (responseData is Map) {
      root = Map<String, dynamic>.from(responseData);
    }
    if (root == null) {
      return const V2FeedPage(articles: [], page: 1, hasMore: false);
    }

    final data = root['data'];
    Map<String, dynamic>? payload;
    if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else if (root.containsKey('items')) {
      payload = root;
    }

    if (payload == null) {
      return const V2FeedPage(articles: [], page: 1, hasMore: false);
    }

    final articles = fromItems(payload['items'] ?? payload['articles'] ?? payload['results']);
    final page = _int(payload['page']) ?? 1;
    // Honor explicit false — do not infer hasMore from page size alone.
    final hasMore = payload['hasNextPage'] == true ||
        payload['has_more'] == true ||
        payload['hasMore'] == true;
    final mode = _str(payload['mode'] ?? payload['sortMode']);

    return V2FeedPage(
      articles: articles,
      page: page,
      hasMore: hasMore,
      mode: mode,
      limit: _int(payload['limit']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  /// True when [name] is an ingestion/adapter label, not a user-facing brand.
  ///
  /// Docs: do not expose adapter keys (`generic_rss`, `newsdata`) as display names.
  static bool isIngestionProviderLabel(String? name) =>
      NewsArticleSummaryX.isIngestionProviderLabel(name);

  /// Picks the original publisher brand for UI attribution.
  ///
  /// Prefers real source/attribution fields over nested `publisher.name` when
  /// that name is an ingestion provider (e.g. "NewsData Aggregator").
  static String? resolveOriginalPublisherName({
    String? sourceName,
    String? nestedSourceName,
    String? originalPublisher,
    String? attributionName,
    String? publisherName,
    String? sourceId,
  }) {
    final candidates = <String?>[
      sourceName,
      nestedSourceName,
      originalPublisher,
      attributionName,
      publisherName,
      sourceId,
    ];
    for (final c in candidates) {
      final s = c?.trim();
      if (s == null || s.isEmpty) continue;
      if (NewsArticleSummaryX.isIngestionProviderLabel(s)) continue;
      return s;
    }
    return null;
  }
}

class V2FeedPage {
  const V2FeedPage({
    required this.articles,
    required this.page,
    required this.hasMore,
    this.mode,
    this.limit,
  });

  final List<NewsArticle> articles;
  final int page;
  final bool hasMore;
  final String? mode;
  final int? limit;
}
