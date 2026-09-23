import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:newson/features/news_detail/domain/article_detail_analytics.dart';

void main() {
  group('V2 article detail feature flag', () {
    test('defaults OFF so V1 detail remains unchanged', () {
      final config = RemoteConfigModel();
      expect(V2FeatureFlags.newArticleDetail(config), isFalse);
    });

    test('Remote Config can enable V2 article detail', () {
      final config = RemoteConfigModel(v2NewArticleDetailEnabled: true);
      expect(V2FeatureFlags.newArticleDetail(config), isTrue);
    });
  });

  group('ArticleDetailAnalytics', () {
    NewsArticle article({
      String? v2,
      String? status,
      String? link,
    }) {
      return NewsArticle(
        title: 'Headline',
        newsId: 'nid-1',
        v2Summary: v2,
        summaryStatus: status,
        link: link,
      );
    }

    test('tracks summary_view only when Cut is available and not yet tracked',
        () {
      final available = article(v2: 'Cut text', status: 'available');
      expect(
        ArticleDetailAnalytics.shouldTrackSummaryView(
          article: available,
          alreadyTracked: false,
        ),
        isTrue,
      );
      expect(
        ArticleDetailAnalytics.shouldTrackSummaryView(
          article: available,
          alreadyTracked: true,
        ),
        isFalse,
      );
    });

    test('does not track summary_view when Cut unavailable', () {
      final missing = article(status: 'unavailable');
      expect(
        ArticleDetailAnalytics.shouldTrackSummaryView(
          article: missing,
          alreadyTracked: false,
        ),
        isFalse,
      );
      expect(missing.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
      expect(missing.newsOnCutText, isNull);
    });

    test('news_open / bookmark / share params use newsId only', () {
      final a = article(v2: 'Cut');
      expect(ArticleDetailAnalytics.newsOpenParams(a), {'newsId': 'nid-1'});
      expect(ArticleDetailAnalytics.bookmarkParams(a), {'newsId': 'nid-1'});
      expect(ArticleDetailAnalytics.shareParams(a), {'newsId': 'nid-1'});
    });

    test('full_article_click params include newsId + url (no secrets)', () {
      final a = article(link: 'https://publisher.example/story');
      final params = ArticleDetailAnalytics.fullArticleParams(
        article: a,
        url: a.canonicalArticleUrl!,
      );
      expect(params['newsId'], 'nid-1');
      expect(params['url'], 'https://publisher.example/story');
      expect(params.containsKey('token'), isFalse);
      expect(params.containsKey('email'), isFalse);
    });

    test('original article CTA uses canonical URL from link', () {
      final a = article(link: 'https://example.com/a');
      expect(a.canonicalArticleUrl, 'https://example.com/a');
    });
  });

  group('NewsOn Cuts display contract', () {
    test('available Cut exposes backend text only', () {
      final a = NewsArticle.fromJson({
        'title': 'T',
        '_id': 'x1',
        'v2_summary': 'Backend cut',
        'summary_status': 'available',
        'description': 'Should not be labeled as Cut',
        'category': ['Politics'],
        'source_name': 'Reuters',
        'link': 'https://reuters.example/story',
      });
      expect(a.newsOnCutText, 'Backend cut');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.available);
      expect(a.category, ['Politics']);
      expect(a.publisherDisplayName, 'Reuters');
    });

    test('unavailable Cut has no fabricated text', () {
      final a = NewsArticle.fromJson({
        'title': 'T',
        '_id': 'x2',
        'description': 'Plain description',
        'summary_status': 'unavailable',
      });
      expect(a.newsOnCutText, isNull);
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
      expect(
        NewsSummaryResolver.descriptionFallback(a),
        'Plain description',
      );
    });
  });
}
