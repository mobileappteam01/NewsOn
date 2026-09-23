import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/features/news/domain/news_summary.dart';

void main() {
  NewsArticle article({
    String? v2,
    String? ai,
    String? status,
    String? description,
    String? link,
    String? sourceUrl,
    String? sourceName,
  }) {
    return NewsArticle(
      title: 'Test headline',
      v2Summary: v2,
      aiSummary: ai,
      summaryStatus: status,
      description: description,
      link: link,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      newsId: 'abc123',
    );
  }

  group('NewsSummaryResolver', () {
    test('prefers v2Summary over aiSummary', () {
      final a = article(v2: 'V2 cut text here', ai: 'Legacy AI');
      expect(a.newsOnCutText, 'V2 cut text here');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.available);
    });

    test('falls back to legacy aiSummary', () {
      final a = article(ai: 'Legacy summary');
      expect(a.newsOnCutText, 'Legacy summary');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.available);
    });

    test('does not treat description as NewsOn Cut', () {
      final a = article(description: 'Just a description');
      expect(a.newsOnCutText, isNull);
      expect(
        NewsSummaryResolver.descriptionFallback(a),
        'Just a description',
      );
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
    });

    test('pending status', () {
      final a = article(status: 'pending');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.pending);
    });

    test('failed status', () {
      final a = article(status: 'failed');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.failed);
    });

    test('available status without text becomes unavailable', () {
      final a = article(status: 'available');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
    });
  });

  group('NewsArticle V2 parsing', () {
    test('parses v2_summary and summary_status', () {
      final a = NewsArticle.fromJson({
        'title': 'Hello',
        'v2_summary': 'Sixty word cut',
        'summary_status': 'available',
        'source_name': 'BBC',
        'link': 'https://example.com/story',
        '_id': 'id1',
      });
      expect(a.v2Summary, 'Sixty word cut');
      expect(a.summaryStatus, 'available');
      expect(a.publisherDisplayName, 'BBC');
      expect(a.canonicalArticleUrl, 'https://example.com/story');
      expect(a.analyticsNewsId, 'id1');
    });

    test('publisherDisplayName hides NewsData Aggregator', () {
      final a = NewsArticle.fromJson({
        'title': 'Hello',
        'source_name': 'NewsData Aggregator',
        '_id': 'id1',
      });
      expect(a.publisherDisplayName, 'Publisher');
      expect(a.publisherDisplayName, isNot(contains('NewsData')));
    });

    test('canonicalUrl prefixes https when missing scheme', () {
      final a = article(sourceUrl: 'www.example.com/a');
      expect(a.canonicalArticleUrl, 'https://www.example.com/a');
    });

    test('legacy articles without V2 fields still parse', () {
      final a = NewsArticle.fromJson({
        'title': 'Old',
        'ai_summary': 'old cut',
      });
      expect(a.v2Summary, isNull);
      expect(a.newsOnCutText, 'old cut');
    });
  });
}
