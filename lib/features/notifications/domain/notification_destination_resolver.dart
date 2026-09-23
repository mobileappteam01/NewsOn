import '../data/notification_payload.dart';
import 'notification_destination.dart';

/// Maps Phase 7 payload types to allowlisted destinations.
///
/// Never trusts [NotificationPayload.route] as an executable path.
abstract final class NotificationDestinationResolver {
  static const allowedTypes = {
    'news_article',
    'news_cut',
    'category',
    'publisher',
    'home',
  };

  static NotificationDestination resolve(NotificationPayload? payload) {
    if (payload == null) return const HomeDestination();

    switch (payload.type) {
      case 'news_article':
        final id = payload.articleId?.trim() ?? '';
        if (id.isEmpty) return const HomeDestination();
        return ArticleDestination(articleId: id);

      case 'news_cut':
        final id = payload.articleId?.trim() ?? '';
        if (id.isEmpty) return const HomeDestination();
        return ArticleDestination(articleId: id, fromCut: true);

      case 'category':
        final id = payload.categoryId?.trim() ?? '';
        if (id.isEmpty) {
          // Fall back to parsing allowlisted /category/:id from route hint only.
          final fromRoute = _idFromPrefixedRoute(payload.route, '/category/');
          if (fromRoute == null) return const HomeDestination();
          return CategoryDestination(fromRoute);
        }
        return CategoryDestination(id);

      case 'publisher':
        final id = payload.publisherId?.trim() ?? '';
        if (id.isEmpty) {
          final fromRoute = _idFromPrefixedRoute(payload.route, '/publisher/');
          if (fromRoute == null) return const HomeDestination();
          return PublisherDestination(fromRoute);
        }
        return PublisherDestination(id);

      case 'home':
        return const HomeDestination();

      default:
        // Unknown type → inbox/home fallback (never execute raw route).
        return const InboxDestination();
    }
  }

  /// Only extracts id when route matches a known prefix allowlist.
  static String? _idFromPrefixedRoute(String? route, String prefix) {
    final r = route?.trim() ?? '';
    if (!r.startsWith(prefix)) return null;
    final id = r.substring(prefix.length).split('/').first.trim();
    if (id.isEmpty || id.contains('..') || id.contains('://')) return null;
    return id;
  }
}
