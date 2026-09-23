import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/notifications/data/notification_payload.dart';
import 'package:newson/features/notifications/domain/notification_preferences_model.dart';

void main() {
  test('V2 notifications flag defaults OFF', () {
    final c = RemoteConfigModel();
    expect(V2FeatureFlags.notifications(c), isFalse);
    expect(c.v2NotificationsEnabled, isFalse);
  });

  test('notification_open event name is stable', () {
    expect(AnalyticsEvents.notificationOpen, 'notification_open');
  });

  test('campaignId propagates into dedupe key', () {
    final p = NotificationPayload.tryParse({
      'type': 'home',
      'campaignId': 'c123',
    })!;
    expect(p.dedupeKey, contains('c123'));
  });

  test('preferences defaults are enabled (backend-compatible)', () {
    const p = NotificationPreferences();
    expect(p.notificationsEnabled, isTrue);
    expect(p.breakingNewsEnabled, isTrue);
    expect(p.categoryNotificationsEnabled, isTrue);
    expect(p.publisherNotificationsEnabled, isTrue);
  });

  test('preferences parse from json', () {
    final p = NotificationPreferences.fromJson({
      'notificationsEnabled': false,
      'breakingNewsEnabled': true,
      'categoryNotificationsEnabled': 'false',
      'publisherNotificationsEnabled': true,
    });
    expect(p.notificationsEnabled, isFalse);
    expect(p.categoryNotificationsEnabled, isFalse);
  });
}
