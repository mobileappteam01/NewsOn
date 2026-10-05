import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/features/notifications/data/notification_preferences_api.dart';
import 'package:newson/features/notifications/domain/notification_preferences_model.dart';
import 'package:newson/features/notifications/presentation/notification_preferences.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';

NewsArticle _article(String id, {String lang = 'en'}) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'T $id',
      language: lang,
    );

class _FakePrefsApi extends NotificationPreferencesApi {
  _FakePrefsApi(
    this.stored, {
    this.failUpdate = false,
    this.failFetch = false,
    this.delayMs = 0,
  });

  NotificationPreferences stored;
  final bool failUpdate;
  bool failFetch;
  int delayMs;
  int updates = 0;
  NotificationPreferences? lastPatch;

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (failFetch) throw StateError('fetch_failed');
    return stored;
  }

  @override
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    updates++;
    lastPatch = prefs;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (failUpdate) return false;
    stored = prefs;
    return true;
  }
}

void main() {
  group('Issue1 email share ID sanitization', () {
    test('strips trailing email punctuation from V2 https URLs', () {
      const id = '6ab6f5bd4cdeb7e76a694d55';
      for (final suffix in ['.', ',', ')', ';', '…']) {
        final uri = Uri.parse('https://v2-api.newson.app/v2/news/$id$suffix');
        expect(DeepLinkConstants.parseV2ArticleId(uri), id, reason: suffix);
      }
    });

    test('query params do not break id extraction', () {
      final uri = Uri.parse(
        'https://v2-api.newson.app/v2/news/6ab6f5bd4cdeb7e76a694d55?utm_source=email',
      );
      expect(
        DeepLinkConstants.parseV2ArticleId(uri),
        '6ab6f5bd4cdeb7e76a694d55',
      );
    });

    test('canonical share host remains v2-api', () {
      final uri = DeepLinkConstants.buildV2HttpsDeepLink('abc');
      expect(uri.host, 'v2-api.newson.app');
      expect(uri.path, '/v2/news/abc');
    });
  });

  group('Issue2 username placeholder rejection', () {
    test('V2 staging is treated as placeholder', () {
      expect(V2AccountProfile.isPlaceholderUsername('V2 staging'), isTrue);
      expect(V2AccountProfile.isPlaceholderUsername('V2 Staging User'), isTrue);
      expect(V2AccountProfile.isPlaceholderUsername('v2-staging'), isTrue);
      expect(V2AccountProfile.isPlaceholderUsername('Karthi'), isFalse);
    });

    test('sanitizeUsername falls back to firstName then email local-part', () {
      expect(
        V2AccountProfile.sanitizeUsername(
          'V2 staging',
          firstName: 'Karthi',
          email: 'k@example.com',
        ),
        'Karthi',
      );
      expect(
        V2AccountProfile.sanitizeUsername(
          'V2 staging',
          firstName: '',
          email: 'nova@example.com',
        ),
        'nova',
      );
      expect(
        V2AccountProfile.sanitizeUsername(
          'V2 staging',
          firstName: '',
          email: '',
        ),
        '',
      );
    });

    test('GET parse strips placeholder username', () {
      final profile = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'profile': {
            'id': 'u1',
            'username': 'V2 staging',
            'firstName': 'Ada',
            'lastName': 'Lovelace',
            'email': 'ada@example.com',
          },
        },
      })!;
      expect(profile.username, 'Ada');
      expect(profile.username.toLowerCase(), isNot(contains('staging')));
    });
  });

  group('Issue3 notification toggle races', () {
    test('ON→OFF persists and rapid taps keep latest OFF', () async {
      final api = _FakePrefsApi(
        const NotificationPreferences(notificationsEnabled: true),
      );
      final c = NotificationPreferencesController(api: api);
      await c.load();
      expect(c.prefs.notificationsEnabled, isTrue);

      await c.setNotificationsEnabled(false);
      expect(c.prefs.notificationsEnabled, isFalse);
      expect(api.lastPatch?.notificationsEnabled, isFalse);

      api.delayMs = 40;
      final f1 = c.setNotificationsEnabled(true);
      final f2 = c.setNotificationsEnabled(false);
      await Future.wait([f1, f2]);
      expect(c.prefs.notificationsEnabled, isFalse);
    });

    test('failed GET does not snap known OFF back to ON', () async {
      final api = _FakePrefsApi(
        const NotificationPreferences(notificationsEnabled: false),
      );
      final c = NotificationPreferencesController(api: api);
      await c.load();
      expect(c.prefs.notificationsEnabled, isFalse);
      api.failFetch = true;
      await c.load();
      expect(c.prefs.notificationsEnabled, isFalse);
    });

    test('failed PATCH rolls back when no newer queue', () async {
      final api = _FakePrefsApi(
        const NotificationPreferences(notificationsEnabled: true),
        failUpdate: true,
      );
      final c = NotificationPreferencesController(api: api);
      await c.load();
      await c.setNotificationsEnabled(false);
      expect(c.prefs.notificationsEnabled, isTrue);
      expect(c.error, 'update_failed');
    });
  });

  group('Issue4 refresh queues language changes', () {
    test('refresh while in-flight is not dropped', () async {
      var language = 'en';
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => language,
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return V2FeedPage(
            articles: [_article('a$calls', lang: language)],
            page: page,
            hasMore: false,
          );
        },
      );

      final first = controller.refresh();
      language = 'ta';
      final second = controller.refresh();
      await Future.wait([first, second]);
      expect(calls, greaterThanOrEqualTo(2));
      expect(controller.state.articles, isNotEmpty);
    });
  });

  group('Issue5 city capitalization', () {
    test('first letter uppercase examples', () {
      expect(V2AccountProfile.capitalizeCity('chennai'), 'Chennai');
      expect(V2AccountProfile.capitalizeCity('Chennai'), 'Chennai');
      expect(V2AccountProfile.capitalizeCity('CHENNAI'), 'CHENNAI');
      expect(V2AccountProfile.capitalizeCity('cHennai'), 'CHennai');
      expect(V2AccountProfile.capitalizeCity(''), '');
      expect(V2AccountProfile.capitalizeCity('c'), 'C');
    });

    test('PATCH body capitalizes city', () {
      const profile = V2AccountProfile(
        id: 'u1',
        username: 'nova',
        firstName: 'N',
        lastName: 'L',
        email: 'a@b.c',
        city: '',
      );
      final body = profile.changedPatchBody(
        nextUsername: 'nova',
        nextFirstName: 'N',
        nextLastName: 'L',
        nextMobileNumber: '',
        nextDateOfBirthYmd: null,
        nextCountry: '',
        nextCity: 'chennai',
      );
      expect(body['city'], 'Chennai');
    });
  });
}
