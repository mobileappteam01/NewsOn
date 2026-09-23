import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_service.dart';
import 'package:newson/data/services/api_service.dart';

void main() {
  group('AnalyticsService.buildTrackBody', () {
    test('uses eventName and promotes newsId to top-level', () {
      final body = AnalyticsService.buildTrackBody(
        eventName: 'news_open',
        sessionId: 'sess_1',
        platform: 'android',
        timestamp: DateTime.utc(2026, 9, 16, 12),
        params: {'newsId': '6aa66ca2f803765f25d11b62'},
      );

      expect(body['eventName'], 'news_open');
      expect(body.containsKey('event'), isFalse);
      expect(body['newsId'], '6aa66ca2f803765f25d11b62');
      expect(body.containsKey('params'), isFalse);
      expect(body['sessionId'], 'sess_1');
    });

    test('rejects titles and non-ObjectId newsIds', () {
      final body = AnalyticsService.buildTrackBody(
        eventName: 'news_open',
        sessionId: 'sess_x',
        platform: 'android',
        params: {'newsId': 'Some Article Title About Markets'},
      );
      expect(body.containsKey('newsId'), isFalse);

      final newsDataId = AnalyticsService.buildTrackBody(
        eventName: 'news_open',
        sessionId: 'sess_y',
        platform: 'android',
        params: {'newsId': 'newsdata-abc-123'},
      );
      expect(newsDataId.containsKey('newsId'), isFalse);
    });

    test('accepts 24-char Mongo ObjectIds only', () {
      const oid = '6ab1d4fda5abc256076d157e';
      final body = AnalyticsService.buildTrackBody(
        eventName: 'news_open',
        sessionId: 'sess_z',
        platform: 'ios',
        params: {'newsId': oid},
      );
      expect(body['newsId'], oid);
    });

    test('maps newsLanguage → language; extras → metadata', () {
      final body = AnalyticsService.buildTrackBody(
        eventName: 'language_change',
        sessionId: 'sess_2',
        platform: 'android',
        params: {
          'newsLanguage': 'tamil',
          'queryLength': 7,
        },
      );

      expect(body['language'], 'tamil');
      expect(body['metadata'], containsPair('queryLength', 7));
    });

    test('publisherId top-level; publisherName in metadata', () {
      final body = AnalyticsService.buildTrackBody(
        eventName: 'publisher_view',
        sessionId: 'sess_3',
        platform: 'android',
        params: {
          'publisherId': '691c40dc9f4d6c8006c3bf04',
          'publisherName': 'Example',
        },
      );

      expect(body['publisherId'], '691c40dc9f4d6c8006c3bf04');
      expect(body['metadata'], containsPair('publisherName', 'Example'));
    });

    test('normalizes iOS / TargetPlatform names to ios|android|web', () {
      expect(AnalyticsService.normalizePlatform('iOS'), 'ios');
      expect(AnalyticsService.normalizePlatform('Android'), 'android');
      expect(
        AnalyticsService.buildTrackBody(
          eventName: 'session_start',
          sessionId: 's',
          platform: 'iOS',
        )['platform'],
        'ios',
      );
    });
  });

  group('AnalyticsService auth bearer resolution', () {
    test('anonymous when logged out', () {
      expect(
        AnalyticsService.resolveOptionalBearer(
          isLoggedIn: false,
          token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.stale',
          skipAfterInvalidToken: false,
        ),
        isNull,
      );
    });

    test('attaches token when logged in', () {
      expect(
        AnalyticsService.resolveOptionalBearer(
          isLoggedIn: true,
          token: 'valid.jwt.token',
          skipAfterInvalidToken: false,
        ),
        'valid.jwt.token',
      );
    });

    test('skips bearer after invalid-token rejection', () {
      expect(
        AnalyticsService.resolveOptionalBearer(
          isLoggedIn: true,
          token: 'stale.jwt.token',
          skipAfterInvalidToken: true,
        ),
        isNull,
      );
    });

    test('detects 403 Invalid Token responses', () {
      expect(
        AnalyticsService.isInvalidTokenResponse(
          statusCode: 403,
          error: 'Invalid Token',
        ),
        isTrue,
      );
      expect(
        AnalyticsService.isInvalidTokenResponse(
          statusCode: 403,
          error: 'Access forbidden.',
        ),
        isTrue,
      );
      expect(
        AnalyticsService.isInvalidTokenResponse(
          statusCode: 500,
          error: 'Invalid Token',
        ),
        isFalse,
      );
      expect(
        AnalyticsService.isInvalidTokenResponse(
          statusCode: 201,
          error: null,
        ),
        isFalse,
      );
    });
  });

  group('ApiService.headersForLog', () {
    test('never exposes Authorization bearer value', () {
      final safe = ApiService.headersForLog({
        'Authorization': 'Bearer super.secret.jwt.value',
        'Content-Type': 'application/json',
      });
      expect(safe['Authorization'], 'Bearer token added to request');
      expect(safe['Content-Type'], 'application/json');
      expect(safe.values.join(' '), isNot(contains('super.secret')));
    });
  });
}
