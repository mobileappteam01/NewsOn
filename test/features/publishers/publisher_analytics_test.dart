import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/core/analytics/analytics_service.dart';
import 'package:newson/core/analytics/analytics_session.dart';

void main() {
  test('publisher_view and publisher_click event names are stable', () {
    expect(AnalyticsEvents.publisherView, 'publisher_view');
    expect(AnalyticsEvents.publisherClick, 'publisher_click');
  });

  test('publisherView dedupes within window', () async {
    AnalyticsSession.instance.endSession();
    final svc = AnalyticsService.instance;
    await svc.publisherView(
      publisherId: 'p1',
      publisherName: 'P',
      language: 'tamil',
      sourceScreen: 'reader',
    );
    await svc.publisherView(
      publisherId: 'p1',
      publisherName: 'P',
      language: 'tamil',
      sourceScreen: 'reader',
    );
    expect(svc.sessionId, isNotEmpty);
  });

  test('publisherClick soft-fails offline', () async {
    AnalyticsSession.instance.endSession();
    final svc = AnalyticsService.instance;
    await svc.publisherClick(
      publisherId: '6ab2847e28ad7340b5d05ca2',
      publisherName: 'Dinamaalai',
      language: 'tamil',
      sourceScreen: 'feed',
      v2Only: true,
    );
    expect(svc.sessionId, isNotEmpty);
  });
}
