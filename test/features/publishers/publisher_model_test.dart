import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/news/domain/news_summary.dart';
import 'package:newson/features/publishers/domain/publisher_article_filter.dart';
import 'package:newson/features/publishers/domain/publisher_model.dart';
import 'package:newson/features/publishers/domain/publisher_url_validator.dart';

NewsArticle _article({
  String id = '1',
  String? sourceName,
  String? sourceId,
  String? publisherId,
  String? sourceUrl,
}) {
  return NewsArticle(
    articleId: id,
    newsId: id,
    title: 'Title $id',
    link: 'https://example.com/$id',
    sourceName: sourceName,
    sourceId: sourceId,
    publisherId: publisherId,
    sourceUrl: sourceUrl,
    sourceIcon: 'https://cdn.example/icon.png',
  );
}

void main() {
  group('PublisherModel', () {
    test('parses backend json fields without fabricating description', () {
      final p = PublisherModel.fromJson({
        '_id': 'pub1',
        'name': 'The Hindu',
        'slug': 'the-hindu',
        'logoUrl': 'https://cdn.example/logo.png',
        'websiteUrl': 'https://www.thehindu.com',
        'isActive': true,
      });
      expect(p.id, 'pub1');
      expect(p.name, 'The Hindu');
      expect(p.slug, 'the-hindu');
      expect(p.description, isNull);
      expect(p.trustedWebsiteUrl, 'https://www.thehindu.com');
    });

    test('inactive publisher is marked inactive', () {
      final p = PublisherModel.fromJson({
        'id': 'x',
        'name': 'X',
        'isActive': false,
      });
      expect(p.isActive, isFalse);
    });

    test('fromArticleProvenance preserves legacy source fields', () {
      final a = _article(sourceName: 'BBC', sourceId: 'bbc');
      final p = PublisherModel.fromArticleProvenance(
        displayName: a.publisherDisplayName,
        publisherId: a.publisherId,
        sourceId: a.sourceId,
        sourceName: a.sourceName,
        sourceUrl: a.sourceUrl,
        sourceIcon: a.sourceIcon,
      );
      expect(p.displayName, 'BBC');
      expect(p.sourceId, 'bbc');
      expect(p.logoUrl, isNotNull);
    });

    test('article publisherId parsing', () {
      final a = NewsArticle.fromJson({
        'title': 'T',
        'publisher_id': 'pub99',
        'source_name': 'Demo',
      });
      expect(a.publisherId, 'pub99');
      expect(a.publisherRouteKey, 'pub99');
    });

    test('V1 fallback when publisherId absent uses source/name', () {
      final a = _article(sourceName: 'Dinamalar', sourceId: 'dinamalar');
      expect(a.publisherId, isNull);
      expect(a.publisherRouteKey, 'dinamalar');
    });
  });

  group('PublisherArticleFilter', () {
    test('matches by sourceName and dedupes', () {
      final pub = PublisherModel(id: 'bbc', name: 'BBC', sourceName: 'BBC');
      final list = [
        _article(id: '1', sourceName: 'BBC'),
        _article(id: '1', sourceName: 'BBC'),
        _article(id: '2', sourceName: 'Other'),
        _article(id: '3', sourceName: 'BBC'),
      ];
      final filtered = PublisherArticleFilter.apply(list, pub);
      expect(filtered.map((a) => a.articleId), ['1', '3']);
    });

    test('matches by publisherId', () {
      final pub = PublisherModel(id: 'pub1', name: 'P');
      final a = _article(id: '9', publisherId: 'pub1', sourceName: 'Other');
      expect(PublisherArticleFilter.matchesPublisher(a, pub), isTrue);
    });
  });

  group('PublisherUrlValidator', () {
    test('accepts https and normalizes bare domains', () {
      expect(PublisherUrlValidator.isTrustedHttpUrl('https://a.com'), isTrue);
      expect(PublisherUrlValidator.normalize('www.a.com'), 'https://www.a.com');
    });

    test('rejects javascript and empty', () {
      expect(
        PublisherUrlValidator.isTrustedHttpUrl('javascript:alert(1)'),
        isFalse,
      );
      expect(PublisherUrlValidator.isTrustedHttpUrl(''), isFalse);
      expect(PublisherUrlValidator.normalize('not a url'), isNull);
    });
  });

  group('Feature flag', () {
    test('publisher pages default OFF when V2 surfaces off', () {
      final config = RemoteConfigModel();
      expect(V2FeatureFlags.publisherPages(config), isFalse);
    });

    test('publisher pages can be enabled explicitly', () {
      final config = RemoteConfigModel(v2PublisherPagesEnabled: true);
      expect(V2FeatureFlags.publisherPages(config), isTrue);
    });

    test('missing publisher RC key still enables when V2 reader is on', () {
      final config = RemoteConfigModel(
        v2PublisherPagesEnabled: false,
        v2HomeReaderEnabled: true,
      );
      expect(V2FeatureFlags.publisherPages(config), isTrue);
    });

    test('missing publisher RC key still enables when V2 detail is on', () {
      final config = RemoteConfigModel(
        v2PublisherPagesEnabled: false,
        v2NewArticleDetailEnabled: true,
      );
      expect(V2FeatureFlags.publisherPages(config), isTrue);
    });
  });
}
