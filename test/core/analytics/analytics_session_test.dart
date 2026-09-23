import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_session.dart';

void main() {
  test('sessionId is stable within a session', () {
    final session = AnalyticsSession.instance;
    session.endSession();
    final a = session.startSession(forceNew: true);
    final b = session.sessionId;
    expect(a, b);
    expect(a.startsWith('sess_'), isTrue);
  });

  test('endSession rotates id', () {
    final session = AnalyticsSession.instance;
    final first = session.startSession(forceNew: true);
    session.endSession();
    final second = session.startSession(forceNew: true);
    expect(first, isNot(second));
  });
}
