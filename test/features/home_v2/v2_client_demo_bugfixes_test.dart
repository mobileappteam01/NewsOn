import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/services/bookmark_api_service.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/bookmarks/domain/bookmark_list_state.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/features/search/data/recent_searches_store.dart';
import 'package:newson/features/search/data/search_repository.dart';
import 'package:newson/features/search/presentation/news_search_controller.dart';

NewsArticle _bm(String id, {String title = 'Story'}) => NewsArticle(
      articleId: id,
      newsId: id,
      title: title,
      isBookmarked: true,
    );

void main() {
  group('Bug1/3 bookmark list edits + V2 parse', () {
    test('remove first/last/middle without mutating source list', () {
      final a = _bm('aaaaaaaaaaaaaaaaaaaaaaaa');
      final b = _bm('bbbbbbbbbbbbbbbbbbbbbbbb');
      final c = _bm('cccccccccccccccccccccccc');
      final source = [a, b, c];

      final withoutFirst = BookmarkListEdits.remove(source, a.newsId!);
      expect(withoutFirst.map((e) => e.newsId), [b.newsId, c.newsId]);
      expect(source.length, 3);

      final withoutLast = BookmarkListEdits.remove(source, c.newsId!);
      expect(withoutLast.map((e) => e.newsId), [a.newsId, b.newsId]);

      final withoutMid = BookmarkListEdits.remove(source, b.newsId!);
      expect(withoutMid.map((e) => e.newsId), [a.newsId, c.newsId]);

      final empty = BookmarkListEdits.remove(withoutFirst, b.newsId!);
      final empty2 = BookmarkListEdits.remove(empty, c.newsId!);
      expect(empty2, isEmpty);
    });

    test('API failure rollback restores snapshot via add', () {
      final kept = _bm('aaaaaaaaaaaaaaaaaaaaaaaa');
      final live = <NewsArticle>[];
      final restored = BookmarkListEdits.add(live, kept);
      expect(restored.single.newsId, kept.newsId);
    });

    test('missing items key is not a successful empty wipe', () {
      expect(
        BookmarkListResponse.tryFromV2Data({'page': 1, 'limit': 20}),
        isNull,
      );
      final ok = BookmarkListResponse.tryFromV2Data({
        'items': [
          {
            'articleId': 'aaaaaaaaaaaaaaaaaaaaaaaa',
            'title': 'Saved',
          },
        ],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      expect(ok, isNotNull);
      expect(ok!.data, hasLength(1));
      expect(ok.data.single.newsId, 'aaaaaaaaaaaaaaaaaaaaaaaa');
    });

    test('explicit empty items is authoritative empty', () {
      final empty = BookmarkListResponse.tryFromV2Data({
        'items': [],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      expect(empty, isNotNull);
      expect(empty!.data, isEmpty);
      expect(
        BookmarkRefreshResult.success(empty.data).phase,
        BookmarkListPhase.empty,
      );
    });
  });

  group('Bug2 share URL', () {
    test('valid share URL uses /v2/news and parses', () {
      const id = '6ab1d4fda5abc256076d157e';
      final uri = DeepLinkConstants.buildV2HttpsDeepLink(id);
      expect(uri.path, '/v2/news/$id');
      expect(DeepLinkConstants.parseV2ArticleId(uri), id);
    });

    test('invalid/missing id does not parse', () {
      expect(
        DeepLinkConstants.parseV2ArticleId(
          Uri.parse('https://api.newson.app/v2/news/'),
        ),
        isNull,
      );
      expect(
        DeepLinkConstants.parseV2ArticleId(
          Uri.parse('https://api.newson.app/v2/news'),
        ),
        isNull,
      );
    });
  });

  group('Bug5 recent searches submit-only', () {
    test('typing without submit does not persist', () async {
      final store = _MemoryRecentStore();
      final controller = NewsSearchController(
        repository: SearchRepository(
          searchFetcher: ({
            required query,
            required languageCode,
            required appliedRegion,
            required page,
            required limit,
          }) async {
            return NewsResponse(
              status: 'success',
              totalResults: 0,
              results: const [],
              nextPage: null,
            );
          },
        ),
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        recentStore: store,
      );
      await controller.bootstrap();
      controller.onQueryChanged('S');
      controller.onQueryChanged('Sc');
      controller.onQueryChanged('Sch');
      controller.onQueryChanged('Scho');
      controller.onQueryChanged('School');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(store.items, isEmpty);

      await controller.submit('School');
      expect(store.items, ['School']);

      await controller.submit('   ');
      expect(store.items, ['School']);

      await controller.submit('School');
      expect(store.items.where((e) => e == 'School').length, 1);
    });
  });

  group('Bug6/8 soft refresh', () {
    test('keepVisible refresh does not blank ready feed before response',
        () async {
      var calls = 0;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls++;
          if (calls == 1) {
            return V2FeedPage(
              articles: [_bm('aaaaaaaaaaaaaaaaaaaaaaaa')],
              page: 1,
              hasMore: false,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return V2FeedPage(
            articles: [_bm('bbbbbbbbbbbbbbbbbbbbbbbb')],
            page: 1,
            hasMore: false,
          );
        },
      );
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.single.newsId, 'aaaaaaaaaaaaaaaaaaaaaaaa');

      final refreshFuture = controller.refresh(keepVisible: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles, isNotEmpty);
      await refreshFuture;
      expect(controller.state.articles.single.newsId, 'bbbbbbbbbbbbbbbbbbbbbbbb');

      await controller.refresh(keepVisible: true);
      expect(calls, 3);
      final a = controller.refresh(keepVisible: true);
      final b = controller.refresh(keepVisible: true);
      await Future.wait([a, b]);
      expect(calls, lessThanOrEqualTo(4));
    });
  });

  group('Bug9 account reload', () {
    test('save reloads via GET and reopen mapping works', () async {
      final api = _AccountApiWithGetAfterPatch();
      final controller = V2AccountController(api: api);
      await controller.load();
      expect(controller.state.profile?.username, 'seed');

      final ok = await controller.save(
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        mobileNumber: '9999999999',
        dateOfBirthYmd: '1995-04-12',
        country: 'india',
      );
      expect(ok, isTrue);
      expect(api.patchCount, 1);
      expect(api.getCount, greaterThanOrEqualTo(2));
      expect(controller.state.profile?.username, 'nova');
      expect(controller.state.profile?.dateOfBirth, '1995-04-12');

      final reopen = V2AccountController(api: api);
      await reopen.load();
      expect(reopen.state.profile?.username, 'nova');
      expect(reopen.state.profile?.lastName, 'Lee');
      expect(reopen.state.profile?.country, 'india');
    });
  });

  group('Bug11 category capitalization', () {
    test('first letter uppercase, rest preserved', () {
      expect(capitalizeCategoryLabel('business'), 'Business');
      expect(capitalizeCategoryLabel('sports'), 'Sports');
      expect(capitalizeCategoryLabel('Technology'), 'Technology');
      expect(capitalizeCategoryLabel(''), '');
      expect(capitalizeCategoryLabel('  ai  '), 'Ai');
    });
  });
}

class _MemoryRecentStore extends RecentSearchesStore {
  final List<String> items = [];

  @override
  Future<List<String>> load() async => List.of(items);

  @override
  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return List.of(items);
    items.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    items.insert(0, q);
    return List.of(items);
  }

  @override
  Future<void> clear() async => items.clear();
}

class _AccountApiWithGetAfterPatch extends V2AccountApi {
  int patchCount = 0;
  int getCount = 0;
  V2AccountProfile _profile = const V2AccountProfile(
    id: 'u1',
    username: 'seed',
    firstName: 'Seed',
    lastName: 'User',
    email: 'seed@example.com',
    country: 'india',
  );

  @override
  Future<V2AccountProfile> fetchProfile() async {
    getCount++;
    return _profile;
  }

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    patchCount++;
    _profile = V2AccountProfile(
      id: _profile.id,
      username: body['username']?.toString() ?? _profile.username,
      firstName: body['firstName']?.toString() ?? _profile.firstName,
      lastName: body['lastName']?.toString() ?? _profile.lastName,
      email: _profile.email,
      dateOfBirth: body.containsKey('dateOfBirth')
          ? body['dateOfBirth']?.toString()
          : _profile.dateOfBirth,
      mobileNumber: body['mobileNumber']?.toString() ?? _profile.mobileNumber,
      country: body['country']?.toString() ?? _profile.country,
      city: body['city']?.toString() ?? _profile.city,
    );
    return _profile;
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [
        V2RegionOption(slug: 'india', name: 'India'),
      ];
}
