import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/news/domain/news_summary.dart';

void main() {
  group('V2FeedItemMapper', () {
    test('maps Phase 6 search/for-you item fields', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'abc123',
        'title': 'Hello',
        'image': 'https://cdn.example/i.jpg',
        'publisher': {'id': 'pub1', 'name': 'Times'},
        'category': [
          {'id': 'c1', 'name': 'World'},
        ],
        'publishedAt': '2026-01-02T03:04:05.000Z',
        'v2Summary': 'Cut text',
        'canonicalUrl': 'https://example.com/a',
        'language': 'en',
        'link': 'https://example.com/a',
      });

      expect(article, isNotNull);
      expect(article!.newsId, 'abc123');
      expect(article.title, 'Hello');
      expect(article.imageUrl, 'https://cdn.example/i.jpg');
      expect(article.publisherId, 'pub1');
      expect(article.sourceName, 'Times');
      expect(article.v2Summary, 'Cut text');
      expect(article.newsOnCutText, 'Cut text');
      expect(article.category, ['World']);
      expect(article.pubDate, '2026-01-02T03:04:05.000Z');
      expect(article.analyticsNewsId, 'abc123');
      expect(article.publisherRouteKey, 'pub1');
    });

    test('ignores items without articleId', () {
      expect(V2FeedItemMapper.fromItem({'title': 'x'}), isNull);
    });

    test('parseEnvelope unwraps success/data/items', () {
      final page = V2FeedItemMapper.parseEnvelope({
        'success': true,
        'data': {
          'items': [
            {'articleId': '1', 'title': 'A'},
            {'articleId': '1', 'title': 'dup'},
            {'articleId': '2', 'title': 'B'},
          ],
          'page': 2,
          'limit': 20,
          'hasNextPage': true,
          'mode': 'personalized',
        },
      });
      expect(page.articles.map((e) => e.newsId), ['1', '2']);
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
      expect(page.mode, 'personalized');
    });
    test('prefers source_name over NewsData Aggregator publisher.name', () {
      final article = V2FeedItemMapper.fromItem({
        'articleId': 'abc123',
        'title': 'Hello',
        'source_name': 'India Today',
        'publisher': {'id': 'pub1', 'name': 'NewsData Aggregator'},
      });
      expect(article!.sourceName, 'India Today');
      expect(article.publisherDisplayName, 'India Today');
    });
  });
}
