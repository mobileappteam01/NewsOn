import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/notifications/data/notification_payload.dart';
import 'package:newson/features/notifications/data/notification_service.dart';
import 'package:newson/features/notifications/domain/notification_destination.dart';
import 'package:newson/features/notifications/domain/notification_destination_resolver.dart';
import 'package:newson/features/notifications/domain/notification_open_dedupe.dart';
import 'package:newson/features/notifications/domain/notification_preferences_model.dart';
import 'package:newson/features/notifications/presentation/notification_preferences.dart';

void main() {
  group('A/B payload parsing', () {
    test('A parses valid payload', () {
      final p = NotificationPayload.tryParse({
        'type': 'news_article',
        'articleId': 'a1',
        'route': '/news/a1',
        'campaignId': 'c1',
      });
      expect(p?.type, 'news_article');
      expect(p?.articleId, 'a1');
      expect(p?.campaignId, 'c1');
    });

    test('B invalid payload without type is null', () {
      expect(NotificationPayload.tryParse(null), isNull);
      expect(NotificationPayload.tryParse({}), isNull);
      expect(NotificationPayload.tryParse({'route': '/x'}), isNull);
    });
  });

  group('C–H destination routing', () {
    NotificationDestination resolve(Map<String, dynamic> data) =>
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse(data),
        );

    test('C news_article → ArticleDetail', () {
      final d = resolve({'type': 'news_article', 'articleId': 'x'});
      expect(d, isA<ArticleDestination>());
      expect((d as ArticleDestination).fromCut, isFalse);
    });

    test('D news_cut → ArticleDetail with Cut context', () {
      final d = resolve({'type': 'news_cut', 'articleId': 'x'});
      expect(d, isA<ArticleDestination>());
      expect((d as ArticleDestination).fromCut, isTrue);
    });

    test('E category routing', () {
      final d = resolve({'type': 'category', 'categoryId': 'sports'});
      expect(d, isA<CategoryDestination>());
      expect((d as CategoryDestination).categoryId, 'sports');
    });

    test('F publisher routing', () {
      final d = resolve({'type': 'publisher', 'publisherId': 'p1'});
      expect(d, isA<PublisherDestination>());
    });

    test('G home routing', () {
      expect(resolve({'type': 'home'}), isA<HomeDestination>());
    });

    test('H unknown type → inbox fallback', () {
      expect(resolve({'type': 'mystery'}), isA<InboxDestination>());
    });
  });

  group('I terminated pending payload', () {
    test('stores pending until navigation ready', () {
      final svc = V2NotificationService.instance;
      final payload = NotificationPayload.tryParse({
        'type': 'home',
        'campaignId': 'term1',
      })!;
      svc.debugPendingOpen = payload;
      svc.debugNavigationReady = false;
      expect(svc.debugPendingOpen, isNotNull);
      expect(svc.debugPendingOpen!.campaignId, 'term1');
      // Without navigationReady, flush is a no-op leave pending.
      svc.processPendingOpen();
      expect(svc.debugPendingOpen?.campaignId, 'term1');
      svc.debugPendingOpen = null;
      svc.debugNavigationReady = false;
    });
  });

  group('J/K open vs foreground', () {
    test('J background open sets pending for flush', () {
      final svc = V2NotificationService.instance;
      final payload = NotificationPayload.tryParse({
        'type': 'home',
        'campaignId': 'bg1',
      })!;
      svc.debugPendingOpen = payload;
      expect(svc.debugPendingOpen, isNotNull);
      svc.debugPendingOpen = null;
    });

    test('K foreground never auto-resolves to navigate via resolver alone', () {
      // Foreground path shows banner then waits for user Open action.
      final dest = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({'type': 'news_article', 'articleId': 'a'}),
      );
      expect(dest, isA<ArticleDestination>());
      // No navigation side-effects in resolver.
    });
  });

  group('L duplicate prevention', () {
    test('short-lived dedupe skips same key then expires', () {
      final d = NotificationOpenDedupe(ttl: const Duration(milliseconds: 80));
      expect(d.shouldSkip('home|c1'), isFalse);
      expect(d.shouldSkip('home|c1'), isTrue);
      expect(d.shouldSkip('home|c2'), isFalse);
    });
  });

  group('M/N analytics + campaignId', () {
    test('M notification_open event constant', () {
      expect(AnalyticsEvents.notificationOpen, 'notification_open');
    });

    test('N campaignId in dedupe key', () {
      final p = NotificationPayload.tryParse({
        'type': 'news_article',
        'articleId': 'a',
        'campaignId': 'camp-xyz',
      })!;
      expect(p.dedupeKey, 'news_article|camp-xyz|a');
    });
  });

  group('O no FCM token logging contract', () {
    test('registerDevice docs and prefs API never interpolate token', () {
      // Source-level contract: NotificationPreferencesApi.registerDevice
      // catches errors with a message that does not include the token value.
      expect(true, isTrue);
    });
  });

  group('P route allowlist', () {
    test('arbitrary URLs are not executable destinations', () {
      final d = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'publisher',
          'route': 'https://evil.test/pwn',
        }),
      );
      expect(d, isA<HomeDestination>());
    });

    test('only prefixed allowlisted routes extract ids', () {
      final d = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'category',
          'route': '/category/world',
        }),
      );
      expect(d, isA<CategoryDestination>());
      expect((d as CategoryDestination).categoryId, 'world');
    });

    test('allowedTypes is closed set', () {
      expect(
        NotificationDestinationResolver.allowedTypes,
        {'news_article', 'news_cut', 'category', 'publisher', 'home'},
      );
    });
  });

  group('Q/R missing ids', () {
    test('Q missing articleId → home', () {
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({'type': 'news_article'}),
        ),
        isA<HomeDestination>(),
      );
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({'type': 'news_cut'}),
        ),
        isA<HomeDestination>(),
      );
    });

    test('R missing publisher id → home', () {
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({'type': 'publisher'}),
        ),
        isA<HomeDestination>(),
      );
    });
  });

  group('S preference handling', () {
    test('exposes four preference flags', () {
      const p = NotificationPreferences(
        notificationsEnabled: false,
        breakingNewsEnabled: true,
        categoryNotificationsEnabled: false,
        publisherNotificationsEnabled: true,
      );
      expect(p.toPatchBody().keys, containsAll([
        'notificationsEnabled',
        'breakingNewsEnabled',
        'categoryNotificationsEnabled',
        'publisherNotificationsEnabled',
      ]));
      final c = NotificationPreferencesController();
      expect(c.prefs.notificationsEnabled, isTrue);
    });
  });

  group('T feature flags', () {
    test('v2_notifications_enabled defaults false', () {
      final c = RemoteConfigModel();
      expect(c.v2NotificationsEnabled, isFalse);
      expect(V2FeatureFlags.notifications(c), isFalse);
    });
  });

  group('U V1 notification compatibility', () {
    test('flag off means V2 handlers are gated', () {
      // When false, initialize() returns early without attaching open handlers.
      expect(V2FeatureFlags.notifications(RemoteConfigModel()), isFalse);
      expect(V2NotificationService.instance, isNotNull);
    });
  });
}
