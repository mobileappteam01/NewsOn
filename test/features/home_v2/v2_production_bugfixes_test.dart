import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';
import 'package:newson/core/utils/stories_count_text.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_news_text_scale.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_display_page.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/notifications/data/notification_preferences_api.dart';
import 'package:newson/features/notifications/domain/notification_preferences_model.dart';
import 'package:newson/features/notifications/presentation/notification_preferences.dart';

NewsArticle _article(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

void main() {
  group('story count', () {
    test('interpolates placeholders and English plural', () {
      expect(StoriesCountText.apply('{count} stories', 0), '0 stories');
      expect(StoriesCountText.apply('{count} stories', 1), '1 story');
      expect(StoriesCountText.apply('{{count}} stories', 2), '2 stories');
      expect(StoriesCountText.apply('%count% stories', 50), '50 stories');
      expect(StoriesCountText.apply(r'$count stories', 70), '70 stories');
    });

    test('keeps non-English templates after inserting the number', () {
      expect(StoriesCountText.apply('{count} historias', 50), '50 historias');
      expect(StoriesCountText.apply('{count} கதைகள்', 70), '70 கதைகள்');
      expect(StoriesCountText.apply('{count} कहानियाँ', 1), '1 कहानियाँ');
    });

    test('does not leave a raw key', () {
      expect(StoriesCountText.apply('storiesCount', 50), '50 stories');
    });
  });

  group('reader ad pages', () {
    List<String> shape(int articles) {
      return V2ReaderDisplayPages.build(articles, adsEnabled: true)
          .map((page) => page is V2ReaderAdDisplay
              ? 'ad'
              : 'a${(page as V2ReaderArticleDisplay).articleIndex}')
          .toList();
    }

    test('1, 4, 5, 8, 9, and 16 articles', () {
      expect(shape(1), ['a0']);
      expect(shape(4), ['a0', 'a1', 'a2', 'a3', 'ad']);
      expect(shape(5), ['a0', 'a1', 'a2', 'a3', 'ad', 'a4']);
      expect(shape(8), ['a0', 'a1', 'a2', 'a3', 'ad', 'a4', 'a5', 'a6', 'a7', 'ad']);
      expect(
        shape(9),
        ['a0', 'a1', 'a2', 'a3', 'ad', 'a4', 'a5', 'a6', 'a7', 'ad', 'a8'],
      );
      final sixteen = shape(16);
      expect(sixteen.where((s) => s == 'ad').length, 4);
      expect(sixteen.where((s) => s != 'ad').length, 16);
      expect(sixteen[4], 'ad');
      expect(sixteen[5], 'a4');
    });

    test('ads disabled keeps article pages only', () {
      final pages = V2ReaderDisplayPages.build(8, adsEnabled: false);
      expect(pages.length, 8);
      expect(pages.every((p) => p is V2ReaderArticleDisplay), isTrue);
    });
  });

  group('text size', () {
    test('one shared factor for every V2 reading surface', () {
      V2NewsTextScale.instance.debugReset(16);
      expect(V2NewsTextScale.instance.factor, 1);
      V2NewsTextScale.instance.apply(20);
      expect(V2NewsTextScale.instance.size, 20);
      expect(V2NewsTextScale.instance.factor, 1.25);
      V2NewsTextScale.instance.apply(12);
      expect(V2NewsTextScale.instance.factor, 0.75);
    });
  });

  group('notification preference', () {
    test('patch body is the preference only', () {
      const prefs = NotificationPreferences(notificationsEnabled: false);
      expect(prefs.toPatchBody().containsKey('fcmToken'), isFalse);
      expect(prefs.toPatchBody()['notificationsEnabled'], isFalse);
    });

    test('failure rolls the toggle back', () async {
      final api = _FakePrefsApi(
        const NotificationPreferences(notificationsEnabled: true),
        failUpdate: true,
      );
      final controller = NotificationPreferencesController(api: api);
      await controller.load();
      await controller.setNotificationsEnabled(false);
      expect(controller.prefs.notificationsEnabled, isTrue);
      expect(controller.error, 'update_failed');
      expect(controller.updating, isFalse);
    });

    test('success keeps the server value', () async {
      final api = _FakePrefsApi(
        const NotificationPreferences(notificationsEnabled: false),
      );
      final controller = NotificationPreferencesController(api: api);
      await controller.load();
      expect(controller.prefs.notificationsEnabled, isFalse);
      await controller.setNotificationsEnabled(true);
      expect(controller.prefs.notificationsEnabled, isTrue);
      expect(api.updates, 1);
    });
  });

  group('home refresh', () {
    test('a second refresh waits until the first finishes', () async {
      final gate = Completer<void>();
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(
          selectedCategorySlugs: ['technology'],
        ),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          await gate.future;
          return V2FeedPage(
            articles: [_article('aaaaaaaaaaaaaaaaaaaaaaaa')],
            page: page,
            hasMore: false,
          );
        },
      );

      final first = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final second = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete();
      await first;
      await second;
      expect(calls, 1);
      expect(
        controller.homeFilter?.call().selectedCategorySlugs,
        ['technology'],
      );
    });
  });

  group('share url', () {
    test('one canonical V2 https link, V1 path unchanged', () {
      final v2 = DeepLinkConstants.buildV2HttpsDeepLink('abc123');
      expect(v2.toString(), 'https://api.newson.app/v2/news/abc123');
      expect(
        DeepLinkConstants.parseV2ArticleId(v2),
        'abc123',
      );
      final v1 = DeepLinkConstants.buildHttpsDeepLink('abc123');
      expect(v1.toString(), 'https://api.newson.app/news/abc123');
      expect(DeepLinkConstants.parseV2ArticleId(v1), isNull);
      expect(DeepLinkConstants.parseArticleId(v1), 'abc123');
    });
  });
}

class _FakePrefsApi extends NotificationPreferencesApi {
  _FakePrefsApi(this.stored, {this.failUpdate = false});

  NotificationPreferences stored;
  final bool failUpdate;
  int updates = 0;

  @override
  Future<NotificationPreferences> fetchPreferences() async => stored;

  @override
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    updates++;
    if (failUpdate) return false;
    stored = prefs;
    return true;
  }
}
