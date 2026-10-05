import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/api_service.dart';
import 'package:newson/features/article_feedback/data/v2_article_feedback_api.dart';
import 'package:newson/features/article_feedback/domain/v2_article_feedback.dart';

import 'fake_api_service.dart';

void main() {
  late FakeApiService http;
  String? token;
  late V2ArticleFeedbackApi api;

  setUp(() {
    http = FakeApiService();
    token = 'test-token';
    api = V2ArticleFeedbackApi(apiService: http, readToken: () => token);
  });

  group('Not Interested', () {
    test('POST /api/v2/articles/:id/not-interested on the V2 host', () async {
      await api.markNotInterested(' a1 ');

      expect(http.posts, hasLength(1));
      final call = http.posts.single;
      expect(call.path, '/api/v2/articles/a1/not-interested');
      expect(call.useV2Host, isTrue);
      expect(call.baseUrlOverride, isNull);
      expect(call.bearerToken, 'test-token');
      expect(call.body, isNull);
    });

    test('article id is URL-encoded into the path', () async {
      await api.markNotInterested('a/b c');
      expect(http.posts.single.path, '/api/v2/articles/a%2Fb%20c/not-interested');
    });

    test('server failure throws', () async {
      http.response = ApiResponse(
        success: false,
        data: null,
        error: 'Not found',
        statusCode: 404,
      );
      await expectLater(
        api.markNotInterested('a1'),
        throwsA(isA<V2ArticleFeedbackException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.kind, 'kind', V2ArticleFeedbackFailure.request)),
      );
    });

    test('signed out: throws and sends nothing', () async {
      token = null;
      await expectLater(
        api.markNotInterested('a1'),
        throwsA(isA<V2ArticleFeedbackException>().having(
          (e) => e.kind,
          'kind',
          V2ArticleFeedbackFailure.unauthenticated,
        )),
      );
      expect(http.posts, isEmpty);
    });

    test('empty id: throws and sends nothing', () async {
      await expectLater(
        api.markNotInterested('  '),
        throwsA(isA<V2ArticleFeedbackException>()),
      );
      expect(http.posts, isEmpty);
    });
  });

  group('Report', () {
    test('body is {reason, comment} with the stable reason id', () async {
      await api.reportArticle('a1', V2ReportReason.misinformation, '  Wrong date  ');

      final call = http.posts.single;
      expect(call.path, '/api/v2/articles/a1/report');
      expect(call.useV2Host, isTrue);
      expect(call.baseUrlOverride, isNull);
      expect(call.bearerToken, 'test-token');
      expect(call.body, {'reason': 'misinformation', 'comment': 'Wrong date'});
    });

    test('missing comment is sent as an empty string', () async {
      await api.reportArticle('a1', V2ReportReason.spamMisleading, null);
      expect(http.posts.single.body, {'reason': 'spam_misleading', 'comment': ''});
    });

    test('every reason uses its wire id', () async {
      for (final reason in V2ReportReason.values) {
        await api.reportArticle('a1', reason, 'Enough detail');
      }
      expect(
        http.posts.map((c) => c.body!['reason']),
        [
          'offensive_content',
          'harassment_abuse',
          'misinformation',
          'spam_misleading',
          'other',
        ],
      );
    });

    test('"other" without meaningful text is rejected before sending', () async {
      for (final comment in [null, '', '   ', 'ab', '!!!', '...?']) {
        await expectLater(
          api.reportArticle('a1', V2ReportReason.other, comment),
          throwsA(isA<V2ArticleFeedbackException>().having(
            (e) => e.kind,
            'kind',
            V2ArticleFeedbackFailure.invalid,
          )),
        );
      }
      expect(http.posts, isEmpty);
    });

    test('comment over 500 characters is rejected before sending', () async {
      await expectLater(
        api.reportArticle('a1', V2ReportReason.offensiveContent, 'x' * 501),
        throwsA(isA<V2ArticleFeedbackException>()),
      );
      expect(http.posts, isEmpty);
      await api.reportArticle('a1', V2ReportReason.offensiveContent, 'x' * 500);
      expect(http.posts, hasLength(1));
    });

    test('signed out: throws and sends nothing', () async {
      token = '';
      await expectLater(
        api.reportArticle('a1', V2ReportReason.misinformation, ''),
        throwsA(isA<V2ArticleFeedbackException>()),
      );
      expect(http.posts, isEmpty);
    });

    test('server failure throws', () async {
      http.response = ApiResponse(
        success: false,
        data: null,
        error: 'Server error',
        statusCode: 500,
      );
      await expectLater(
        api.reportArticle('a1', V2ReportReason.misinformation, ''),
        throwsA(isA<V2ArticleFeedbackException>()),
      );
    });
  });

  group('V2ReportForm', () {
    test('submit needs a reason', () {
      expect(V2ReportForm.canSubmit(null, 'anything'), isFalse);
      expect(V2ReportForm.canSubmit(V2ReportReason.misinformation, ''), isTrue);
    });

    test('"other" accepts Indic text', () {
      expect(V2ReportForm.canSubmit(V2ReportReason.other, 'தவறான'), isTrue);
      expect(V2ReportForm.canSubmit(V2ReportReason.other, 'गलत है'), isTrue);
    });
  });

  test('feedback sources never reference the V1 host', () {
    final dir = Directory('lib/features/article_feedback');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final source = file.readAsStringSync();
      expect(source.contains('api.newson.app'), isFalse, reason: file.path);
      expect(source.contains('useV2Host: false'), isFalse, reason: file.path);
    }
  });
}
