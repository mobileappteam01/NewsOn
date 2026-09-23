import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:newson/features/news_detail/domain/article_detail_analytics.dart';

void main() {
  group('Feature flag', () {
    test('OFF keeps V1 article detail path', () {
      expect(
        V2FeatureFlags.newArticleDetail(
          RemoteConfigModel(v2NewArticleDetailEnabled: false),
        ),
        isFalse,
      );
    });

    test('ON enables V2 article detail path', () {
      expect(
        V2FeatureFlags.newArticleDetail(
          RemoteConfigModel(v2NewArticleDetailEnabled: true),
        ),
        isTrue,
      );
    });
  });

  group('Navigation contracts', () {
    test('Search tab opens articles via V2Routes.openArticle', () {
      final src = File(
        'lib/features/search/presentation/v2_search_tab.dart',
      ).readAsStringSync();
      expect(src.contains('V2Routes.openArticle'), isTrue);
    });

    test('For You tab opens articles via V2Routes.openArticle', () {
      final src = File(
        'lib/features/for_you/presentation/v2_for_you_tab.dart',
      ).readAsStringSync();
      expect(src.contains('V2Routes.openArticle'), isTrue);
    });

    test('V2Routes.openArticle is the shared flag-aware entry', () {
      final src = File('lib/app/routing/v2_routes.dart').readAsStringSync();
      expect(src.contains('V2ArticleDetailScreen'), isTrue);
      expect(src.contains('articleId:'), isTrue);
      expect(src.contains('NewsDetailScreen.open'), isTrue);
      expect(src.contains('V2FeatureFlags.newArticleDetail'), isTrue);
    });

    test('V2 Reader Read Original opens V2ArticleDetailScreen by articleId', () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(src.contains('V2ArticleDetailScreen'), isTrue);
      expect(src.contains('articleId:'), isTrue);
      expect(src.contains('FullArticleScreen'), isFalse);
    });

    test('V2 Detail body uses content resolver and V2 detail API', () {
      final src = File(
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('V2ArticleBodyResolver'), isTrue);
      expect(src.contains('V2ArticleDetailApi'), isTrue);
      expect(src.contains('FullArticleScreen'), isFalse);
      expect(src.contains('v2ViewFullArticle'), isFalse);
    });

    test('Deep links use flag-aware NewsDetailScreen.open', () {
      final src = File(
        'lib/data/services/deep_link_service.dart',
      ).readAsStringSync();
      expect(src.contains('NewsDetailScreen.open'), isTrue);
      expect(src.contains('NewsDetailScreen(article:'), isFalse);
    });
  });

  group('Article detail state / Cuts', () {
    NewsArticle article({
      String? cut,
      String? status,
      String? description,
      String? link,
    }) {
      return NewsArticle(
        title: 'Sample story',
        newsId: 'nav-1',
        v2Summary: cut,
        summaryStatus: status,
        description: description,
        link: link ?? 'https://example.com/story',
        sourceName: 'Example News',
        category: const ['World'],
      );
    }

    test('summary available exposes backend Cut only', () {
      final a = article(cut: 'Backend cut', status: 'available');
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.available);
      expect(a.newsOnCutText, 'Backend cut');
      expect(
        ArticleDetailAnalytics.shouldTrackSummaryView(
          article: a,
          alreadyTracked: false,
        ),
        isTrue,
      );
    });

    test('summary unavailable has no fabricated Cut text', () {
      final a = article(
        cut: null,
        status: 'unavailable',
        description: 'Do not show as Cut',
      );
      expect(a.resolvedSummaryStatus, NewsSummaryStatus.unavailable);
      expect(a.newsOnCutText, isNull);
      expect(
        ArticleDetailAnalytics.shouldTrackSummaryView(
          article: a,
          alreadyTracked: false,
        ),
        isFalse,
      );
    });

    test('original article CTA resolves canonical URL', () {
      final a = article(link: 'https://publisher.example/a');
      expect(a.canonicalArticleUrl, 'https://publisher.example/a');
      final params = ArticleDetailAnalytics.fullArticleParams(
        article: a,
        url: a.canonicalArticleUrl!,
      );
      expect(params['newsId'], 'nav-1');
      expect(params['url'], 'https://publisher.example/a');
    });

    test('bookmark and share analytics params are newsId-only', () {
      final a = article(cut: 'x');
      expect(ArticleDetailAnalytics.bookmarkParams(a), {'newsId': 'nav-1'});
      expect(ArticleDetailAnalytics.shareParams(a), {'newsId': 'nav-1'});
      expect(ArticleDetailAnalytics.newsOpenParams(a), {'newsId': 'nav-1'});
    });
  });
}
