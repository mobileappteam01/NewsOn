import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/config/v2_feature_flags.dart';
import '../../data/models/news_article.dart';
import '../../features/news/domain/news_summary.dart';
import '../../features/news_detail/presentation/v2_article_detail_screen.dart';
import '../../features/publishers/presentation/publisher_page.dart';
import '../../providers/remote_config_provider.dart';
import '../../screens/categories/categories_tab.dart';
import '../../features/notifications/presentation/v2_notification_inbox_screen.dart';
import '../../screens/news_detail/news_detail_screen.dart';

/// Central navigation helpers for V2 surfaces (flag-aware).
abstract final class V2Routes {
  /// Opens V2 article detail when enabled; otherwise V1 [NewsDetailScreen].
  static Future<void> openArticle(
    BuildContext context, {
    required NewsArticle article,
    List<NewsArticle>? articles,
    int? initialIndex,
  }) async {
    final config = context.read<RemoteConfigProvider>().config;
    final snapshot = articles != null ? List<NewsArticle>.from(articles) : null;
    var index = initialIndex ??
        (snapshot != null
            ? NewsDetailScreen.indexOfArticle(snapshot, article)
            : 0);
    if (index < 0) index = 0;
    if (snapshot != null && snapshot.isNotEmpty && index >= snapshot.length) {
      index = snapshot.length - 1;
    }

    if (V2FeatureFlags.newArticleDetail(config)) {
      // V2 Detail: fetch GET /api/v2/article/{articleId} (not Cut-as-body).
      // Reader "Read Full Article" and list taps share this screen.
      final id = article.analyticsNewsId;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => V2ArticleDetailScreen(
            articleId: id,
            seedArticle: article,
          ),
          settings: RouteSettings(name: '/v2/article/$id'),
        ),
      );
      return;
    }

    NewsDetailScreen.open(
      context,
      article: article,
      articles: snapshot,
      initialIndex: index,
    );
  }

  /// Opens Publisher page when publisher pages are enabled for this V2 surface.
  ///
  /// Requires a real [publisherId] (source of truth). Route: `/publisher/:id`
  static Future<void> openPublisher(
    BuildContext context, {
    required String publisherId,
    String? publisherName,
    NewsArticle? seedArticle,
    String sourceScreen = 'unknown',
  }) async {
    final config = context.read<RemoteConfigProvider>().config;
    final enabled = V2FeatureFlags.publisherPages(config);
    final id = publisherId.trim();
    final name = (publisherName ?? seedArticle?.publisherDisplayName ?? '')
        .trim();

    debugPrint(
      '[PublisherNavigation] enabled=$enabled '
      'publisherId=${id.isEmpty ? 'missing' : id} '
      'publisherName=${name.isEmpty ? 'missing' : name} '
      'sourceScreen=$sourceScreen',
    );

    if (!enabled) return;
    if (id.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublisherPage(
          publisherKey: id,
          seedArticle: seedArticle,
          sourceScreen: sourceScreen,
        ),
        settings: RouteSettings(name: '/publisher/$id'),
      ),
    );
  }

  /// Convenience: open publisher from an article when [publisherId] is present.
  static Future<void> openPublisherFromArticle(
    BuildContext context,
    NewsArticle article, {
    String sourceScreen = 'article',
    String? language,
  }) async {
    final id = article.publisherId?.trim() ?? '';
    final name = article.publisherDisplayName.trim();
    final enabled = publisherLinksEnabled(context);

    debugPrint(
      '[PublisherTap] screen=$sourceScreen '
      'enabled=$enabled '
      'publisherId=${id.isEmpty ? 'missing' : id} '
      'publisherName=${name.isEmpty ? 'missing' : name}',
    );

    if (id.isEmpty) return;
    if (!enabled) return;

    await AnalyticsService.instance.publisherClick(
      publisherId: id,
      publisherName: name.isEmpty ? null : name,
      language: language,
      sourceScreen: sourceScreen,
      v2Only: true,
    );

    if (!context.mounted) return;

    return openPublisher(
      context,
      publisherId: id,
      publisherName: name.isEmpty ? null : name,
      seedArticle: article,
      sourceScreen: sourceScreen,
    );
  }

  /// True when the article has a real publisherId and the feature flag is on.
  static bool canOpenPublisher(BuildContext context, NewsArticle article) {
    final id = article.publisherId?.trim() ?? '';
    if (id.isEmpty) return false;
    return publisherLinksEnabled(context);
  }

  /// Returns true when publisher chrome should be interactive.
  static bool publisherLinksEnabled(BuildContext context) {
    try {
      final config = context.read<RemoteConfigProvider>().config;
      return V2FeatureFlags.publisherPages(config);
    } catch (_) {
      return false;
    }
  }

  /// Pop to root home (or push [HomeScreen] if needed).
  static Future<void> openHome(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) => route.isFirst);
  }

  /// Opens categories surface. [categoryId] is reserved for future deep filter.
  static Future<void> openCategory(
    BuildContext context, {
    required String categoryId,
  }) async {
    final id = categoryId.trim();
    if (id.isEmpty) {
      await openHome(context);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CategoriesTab(),
        settings: RouteSettings(name: '/category/$id'),
      ),
    );
  }

  /// Opens the V2 notification inbox screen.
  static Future<void> openNotificationInbox(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const V2NotificationInboxScreen(),
        settings: const RouteSettings(name: '/notifications'),
      ),
    );
  }
}
