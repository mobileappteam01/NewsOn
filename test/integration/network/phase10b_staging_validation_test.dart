import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_service.dart';
import 'package:newson/features/audio/domain/article_audio.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/search/domain/search_query_validator.dart';

/// Phase 10B — live staging mapper/API validation.
///
/// Excluded from default suite (`dart_test.yaml` exclude_tags).
///
/// Run:
///   fvm flutter test --tags network test/integration/network/phase10b_staging_validation_test.dart
@Tags(['integration', 'network'])
void main() {
  const base = String.fromEnvironment(
    'NEWSON_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8010',
  );

  Future<Map<String, dynamic>> getJson(String path) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$base$path');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      final res = await req.close().timeout(const Duration(seconds: 12));
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      expect(decoded, isA<Map>());
      return Map<String, dynamic>.from(decoded as Map);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$base$path');
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 12));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close().timeout(const Duration(seconds: 12));
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      expect(decoded, isA<Map>());
      final map = Map<String, dynamic>.from(decoded as Map);
      map['_httpStatus'] = res.statusCode;
      return map;
    } finally {
      client.close(force: true);
    }
  }

  test('staging health is reachable', () async {
    final health = await getJson('/api/health');
    expect(health['success'], isTrue);
    expect(health['status'], 'ok');
  });

  test('V2 search: client rejects <2 chars; staging accepts 2+ and maps fields',
      () async {
    expect(SearchQueryValidator.validate('a'), 'too_short');
    expect(SearchQueryValidator.isValid('ai'), isTrue);

    final short = await getJson('/api/v2/search?q=a&limit=1');
    expect(short['success'], isFalse);

    final populated = await getJson('/api/v2/search?q=chennai&page=1&limit=2');
    expect(populated['success'], isTrue);
    final page = V2FeedItemMapper.parseEnvelope(populated);
    expect(page.articles, isNotEmpty);
    final first = page.articles.first;
    expect(first.newsId, isNotEmpty);
    expect(first.newsId, first.articleId ?? first.newsId);
    expect(first.title, isNotEmpty);
    expect(first.imageUrl, isNotNull);
    expect(first.sourceName, isNotNull);
    expect(first.language, isNotNull);
    expect(first.link ?? first.sourceUrl, isNotNull);

    final page2 = V2FeedItemMapper.parseEnvelope(
      await getJson('/api/v2/search?q=chennai&page=2&limit=2'),
    );
    expect(page2.page, 2);
    expect(page2.articles, isNotEmpty);

    final empty = V2FeedItemMapper.parseEnvelope(
      await getJson('/api/v2/search?q=zzzxqwynotreal999&limit=5'),
    );
    expect(empty.articles, isEmpty);
  });

  test('V2 for-you anonymous_fallback maps without treating empty as failure',
      () async {
    final raw = await getJson('/api/v2/for-you?page=1&limit=3');
    expect(raw['success'], isTrue);
    final page = V2FeedItemMapper.parseEnvelope(raw);
    expect(page.mode, 'anonymous_fallback');
    if (page.articles.isNotEmpty) {
      final a = page.articles.first;
      expect(a.newsId, isNotEmpty);
      // Cuts: preserve when present (do not invent).
      // Some items may have v2Summary; absence is valid.
      expect(a.title, isNotEmpty);
    }
  });

  test('V2 audio unavailable parses without requiring generation', () async {
    final search = await getJson('/api/v2/search?q=chennai&limit=1');
    final page = V2FeedItemMapper.parseEnvelope(search);
    expect(page.articles, isNotEmpty);
    final id = page.articles.first.newsId!;
    final raw = await getJson('/api/v2/audio/article/$id');
    expect(raw['success'], isTrue);
    final data = Map<String, dynamic>.from(raw['data'] as Map);
    final audio = ArticleAudio.fromJson(id, data);
    expect(audio.status, ArticleAudioStatus.unavailable);
    expect(audio.canPlay, isFalse);
  });

  test('analytics track body shape accepted by staging', () async {
    final search = await getJson('/api/v2/search?q=chennai&limit=1');
    final page = V2FeedItemMapper.parseEnvelope(search);
    final newsId = page.articles.first.newsId!;
    final sessionId =
        'phase10b-${DateTime.now().toUtc().millisecondsSinceEpoch}';

    final sessionBody = AnalyticsService.buildTrackBody(
      eventName: 'session_start',
      sessionId: sessionId,
      platform: 'android',
    );
    final sessionRes =
        await postJson(AnalyticsService.trackPath, sessionBody);
    expect(sessionRes['_httpStatus'], anyOf(200, 201));
    expect(sessionRes['success'], isTrue);

    final openBody = AnalyticsService.buildTrackBody(
      eventName: 'news_open',
      sessionId: sessionId,
      platform: 'android',
      params: {'newsId': newsId},
    );
    final openRes = await postJson(AnalyticsService.trackPath, openBody);
    expect(openRes['_httpStatus'], anyOf(200, 201));
    expect(openRes['success'], isTrue);

    final searchBody = AnalyticsService.buildTrackBody(
      eventName: 'search',
      sessionId: sessionId,
      platform: 'android',
      params: {'queryLength': 7},
    );
    final searchRes = await postJson(AnalyticsService.trackPath, searchBody);
    expect(searchRes['success'], isTrue);
  });
}
