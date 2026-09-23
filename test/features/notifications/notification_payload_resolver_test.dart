import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/notifications/data/notification_payload.dart';
import 'package:newson/features/notifications/domain/notification_destination.dart';
import 'package:newson/features/notifications/domain/notification_destination_resolver.dart';

void main() {
  group('NotificationPayload.tryParse', () {
    test('requires type', () {
      expect(NotificationPayload.tryParse({}), isNull);
      expect(NotificationPayload.tryParse({'articleId': 'a'}), isNull);
    });

    test('parses known fields and ignores unknowns', () {
      final p = NotificationPayload.tryParse({
        'type': 'news_article',
        'articleId': 'abc',
        'campaignId': 'camp1',
        'route': '/news/abc',
        'extra': 'ignored',
      });
      expect(p, isNotNull);
      expect(p!.type, 'news_article');
      expect(p.articleId, 'abc');
      expect(p.campaignId, 'camp1');
      expect(p.dedupeKey, contains('camp1'));
    });
  });

  group('NotificationDestinationResolver', () {
    test('news_article and news_cut', () {
      final a = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'news_article',
          'articleId': 'a1',
        }),
      );
      expect(a, isA<ArticleDestination>());
      expect((a as ArticleDestination).fromCut, isFalse);

      final c = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'news_cut',
          'articleId': 'a1',
        }),
      );
      expect(c, isA<ArticleDestination>());
      expect((c as ArticleDestination).fromCut, isTrue);
    });

    test('missing articleId falls back to home', () {
      final d = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({'type': 'news_article'}),
      );
      expect(d, isA<HomeDestination>());
    });

    test('category and publisher', () {
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({
            'type': 'category',
            'categoryId': 'cat1',
          }),
        ),
        isA<CategoryDestination>(),
      );
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({
            'type': 'publisher',
            'publisherId': 'pub1',
          }),
        ),
        isA<PublisherDestination>(),
      );
    });

    test('publisher from allowlisted route hint only', () {
      final d = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'publisher',
          'route': '/publisher/pub99',
        }),
      );
      expect(d, isA<PublisherDestination>());
      expect((d as PublisherDestination).publisherId, 'pub99');
    });

    test('does not execute arbitrary route', () {
      final d = NotificationDestinationResolver.resolve(
        NotificationPayload.tryParse({
          'type': 'publisher',
          'route': 'https://evil.example/x',
        }),
      );
      expect(d, isA<HomeDestination>());
    });

    test('home and unknown', () {
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({'type': 'home'}),
        ),
        isA<HomeDestination>(),
      );
      expect(
        NotificationDestinationResolver.resolve(
          NotificationPayload.tryParse({'type': 'weird'}),
        ),
        isA<InboxDestination>(),
      );
    });

    test('null payload → home', () {
      expect(
        NotificationDestinationResolver.resolve(null),
        isA<HomeDestination>(),
      );
    });
  });
}
