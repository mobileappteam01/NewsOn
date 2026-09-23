import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_service.dart';
import 'package:newson/features/audio/domain/article_audio.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/search/domain/search_query_validator.dart';

/// Phase 10B — maps **real** staging responses captured under
/// `test/fixtures/phase10b/` (not invented mocks).
void main() {
  Map<String, dynamic> loadFixture(String name) {
    final file = File('test/fixtures/phase10b/$name');
    expect(file.existsSync(), isTrue, reason: 'missing fixture $name');
    return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
  }

  test('search fixture maps articleId → newsId and preserves V2 fields', () {
    final raw = loadFixture('search_chennai_p1.json');
    expect(raw['success'], isTrue);
    final page = V2FeedItemMapper.parseEnvelope(raw);
    expect(page.articles.length, greaterThanOrEqualTo(1));
    final a = page.articles.first;
    expect(a.newsId, isNotEmpty);
    final item = ((raw['data'] as Map)['items'] as List).first as Map;
    expect(a.newsId, item['articleId']);
    expect(a.title, item['title']);
    expect(a.imageUrl, item['image']);
    expect(a.sourceName, (item['publisher'] as Map?)?['name']);
    expect(a.language, item['language']);
    expect(a.link, item['link']);
    expect(a.category, isNotEmpty);
  });

  test('empty search fixture yields empty articles (not a crash)', () {
    final page = V2FeedItemMapper.parseEnvelope(loadFixture('search_empty.json'));
    expect(page.articles, isEmpty);
  });

  test('client rejects queries shorter than 2 characters', () {
    expect(SearchQueryValidator.validate('a'), 'too_short');
    expect(SearchQueryValidator.isValid('ai'), isTrue);
  });

  test('for-you anonymous_fallback fixture preserves mode and cuts when present',
      () {
    final raw = loadFixture('for_you_anon.json');
    final page = V2FeedItemMapper.parseEnvelope(raw);
    expect(page.mode, 'anonymous_fallback');
    expect(page.articles, isNotEmpty);
    final withCut = page.articles.where(
      (a) => (a.v2Summary ?? '').trim().isNotEmpty,
    );
    // Staging had at least one Cut in the captured page — do not invent text.
    expect(withCut, isNotEmpty);
    final cut = withCut.first;
    expect(cut.newsId, isNotEmpty);
    expect(cut.v2Summary!.contains('invented'), isFalse);
  });

  test('audio unavailable fixture parses without canPlay', () {
    final raw = loadFixture('audio_unavailable.json');
    final data = Map<String, dynamic>.from(raw['data'] as Map);
    final audio = ArticleAudio.fromJson('fixture-id', data);
    expect(audio.status, ArticleAudioStatus.unavailable);
    expect(audio.canPlay, isFalse);
  });

  test('analytics body from Flutter matches Phase 1D staging contract', () {
    final body = AnalyticsService.buildTrackBody(
      eventName: 'news_open',
      sessionId: 'fixture-session',
      platform: 'android',
      params: {'newsId': '6aa66ca2f803765f25d11b62'},
    );
    expect(body['eventName'], 'news_open');
    expect(body.containsKey('event'), isFalse);
    expect(body['newsId'], '6aa66ca2f803765f25d11b62');
    expect(body.containsKey('params'), isFalse);
  });
}
