import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_effective_categories.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_home_filter_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _article(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

void main() {
  group('Home request semantics', () {
    test('1. saved prefs + no explicit filter → omit category', () {
      final request = V2EffectiveHomeFilter.forRequest(const HomeFilterState());
      final query = request.toQueryParameters(
        language: 'en',
        page: 1,
        limit: 20,
      );
      expect(query.containsKey('category'), isFalse);
      expect(query['language'], 'en');
      // Backend returns categorySource=saved_preferences when prefs exist.
    });

    test('2. explicit filter overrides — category is sent', () {
      final request = V2EffectiveHomeFilter.forRequest(
        const HomeFilterState(selectedCategorySlugs: ['business']),
      );
      expect(
        request.toQueryParameters(language: 'en', page: 1, limit: 20)['category'],
        'business',
      );
    });

    test('3. Clear All restores absent category (saved prefs on server)', () {
      var committed = const HomeFilterState(
        selectedCategorySlugs: ['business'],
        country: 'india',
      );
      committed = committed.cleared();
      final request = V2EffectiveHomeFilter.forRequest(committed);
      final query = request.toQueryParameters(
        language: 'ta',
        page: 1,
        limit: 20,
      );
      expect(query.containsKey('category'), isFalse);
      expect(query.containsKey('country'), isFalse);
      expect(query['language'], 'ta');
    });

    test('4. no saved prefs + no explicit → default feed query', () {
      final controller = V2HomeFilterController();
      expect(controller.hasExplicitCategories, isFalse);
      expect(controller.hasSavedPreferences, isFalse);
      final query = controller.requestFilter.toQueryParameters(
        language: 'en',
        page: 1,
        limit: 20,
      );
      expect(query.keys.toSet(), {'page', 'limit', 'language'});
    });

    test('5. hard restart → request still omits category (backend prefs)', () {
      // After hard restart the temporary filter is empty; category must stay
      // absent so GET /api/v2/home?language=... lets the backend apply prefs.
      final controller = V2HomeFilterController();
      expect(controller.committed.isActive, isFalse);
      expect(
        controller.requestFilter
            .toQueryParameters(language: 'en', page: 1, limit: 20)
            .containsKey('category'),
        isFalse,
      );
    });

    test('6/7. refresh + pagination preserve explicit category', () async {
      final pages = <int>[];
      final cats = <String?>[];
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => V2EffectiveHomeFilter.forRequest(
          const HomeFilterState(selectedCategorySlugs: ['sports']),
        ),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          pages.add(page);
          cats.add(filter.toQueryParameters(
            language: language,
            page: page,
            limit: limit,
          )['category']);
          return V2FeedPage(
            articles: [
              _article(page == 1
                  ? 'aaaaaaaaaaaaaaaaaaaaaaaa'
                  : 'bbbbbbbbbbbbbbbbbbbbbbbb'),
            ],
            page: page,
            hasMore: page == 1,
            categoryFilters: const V2HomeCategoryFilters(
              source: 'explicit',
              categories: ['sports'],
            ),
          );
        },
      );
      await controller.loadInitial();
      await controller.refresh();
      controller.unawaitedLoadMore();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(pages, [1, 1, 2]);
      expect(cats.every((c) => c == 'sports'), isTrue);
    });

    test('8. inspect backend filters.categorySource', () {
      final withPrefs = V2FeedItemMapper.parseEnvelope({
        'success': true,
        'data': {
          'items': [
            {'articleId': 'aaaaaaaaaaaaaaaaaaaaaaaa', 'title': 'A'},
          ],
          'page': 1,
          'limit': 20,
          'hasNextPage': false,
          'filters': {
            'categorySource': 'saved_preferences',
            'categories': [
              {'id': '1', 'name': 'Technology', 'slug': 'technology'},
              {'id': '2', 'name': 'Sports', 'slug': 'sports'},
            ],
          },
        },
      });
      expect(withPrefs.categorySource, 'saved_preferences');
      expect(withPrefs.categoryFilters!.categories, ['technology', 'sports']);
      expect(
        V2HomeCategoryDebug.lines(
          source: withPrefs.categorySource!,
          categories: withPrefs.categoryFilters!.categories,
          itemCount: withPrefs.articles.length,
        ),
        [
          '[V2HomeCategory]',
          'source=saved_preferences',
          'categories=[technology, sports]',
        ],
      );

      final emptySaved = V2FeedItemMapper.parseEnvelope({
        'success': true,
        'data': {
          'items': [],
          'page': 1,
          'hasNextPage': false,
          'filters': {
            'categorySource': 'saved_preferences',
            'categories': [
              {'slug': 'technology', 'name': 'Technology'},
            ],
          },
        },
      });
      expect(emptySaved.categorySource, 'saved_preferences');
      expect(emptySaved.articles, isEmpty);
      expect(
        V2HomeCategoryDebug.lines(
          source: emptySaved.categorySource!,
          categories: emptySaved.categoryFilters!.categories,
          itemCount: emptySaved.articles.length,
        ),
        contains(
          '[V2HomeCategory] saved preferences returned zero matching articles',
        ),
      );

      final explicit = V2FeedItemMapper.parseEnvelope({
        'data': {
          'items': [],
          'filters': {
            'categorySource': 'explicit',
            'categories': [
              {'slug': 'business', 'name': 'Business'},
            ],
          },
        },
      });
      expect(explicit.categorySource, 'explicit');

      final defaults = V2FeedItemMapper.parseEnvelope({
        'data': {
          'items': [
            {'articleId': 'cccccccccccccccccccccccc', 'title': 'C'},
          ],
          'filters': {
            'categorySource': 'default',
            'categories': [],
          },
        },
      });
      expect(defaults.categorySource, 'default');
      expect(defaults.categoryFilters!.categories, isEmpty);
    });

    test('never serializes empty category', () {
      final q = const HomeFilterState(selectedCategorySlugs: ['', '  '])
          .toQueryParameters(language: 'en', page: 1, limit: 20);
      expect(q.containsKey('category'), isFalse);
    });

    test('preference revision bumps notify Home reload listeners', () {
      var bumps = 0;
      void listener() => bumps++;
      V2CategoryPreferenceResolver.revision.addListener(listener);
      V2CategoryPreferenceResolver.bump();
      V2CategoryPreferenceResolver.revision.removeListener(listener);
      expect(bumps, 1);
    });
  });

  group('Account profile', () {
    test('9. profile load from backend payload', () {
      final profile = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'id': 'u1',
          'username': 'nova',
          'firstName': 'Nova',
          'lastName': 'Lee',
          'email': 'nova@example.com',
          'dateOfBirth': '1995-04-12',
          'mobileNumber': '9999999999',
          'country': 'india',
        },
      })!;
      expect(profile.username, 'nova');
      expect(profile.lastName, 'Lee');
      expect(profile.dateOfBirth, '1995-04-12');
      expect(profile.country, 'india');
      expect(profile.mobileNumber, '9999999999');
    });

    test('9b. profile load from nested data.profile envelope', () {
      final profile = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'profile': {
            'id': 'u1',
            'username': 'Karthi',
            'firstName': 'Karthj',
            'lastName': 'Arjunan',
            'email': 'k@e.com',
            'dateOfBirth': '2001-01-01',
            'mobileNumber': '8508748592',
          },
        },
      })!;
      expect(profile.username, 'Karthi');
      expect(profile.firstName, 'Karthj');
      expect(profile.lastName, 'Arjunan');
      expect(profile.dateOfBirth, '2001-01-01');
      expect(profile.mobileNumber, '8508748592');
      expect(profile.country, isEmpty);
    });

    test('10/11. profile update + partial changed-only patch', () {
      const profile = V2AccountProfile(
        id: 'u1',
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        email: 'a@b.c',
        dateOfBirth: '1995-04-12',
        mobileNumber: '9999999999',
        country: 'india',
      );
      final full = profile.toPatchBody(
        username: 'nova2',
        firstName: 'Nova',
        lastName: 'Lee',
        dateOfBirth: '1995-04-12',
        mobileNumber: '8888888888',
        country: 'india',
      );
      expect(full['username'], 'nova2');
      expect(full.containsKey('nickName'), isFalse);

      final partial = profile.changedPatchBody(
        nextUsername: 'nova',
        nextFirstName: 'Nova',
        nextLastName: 'Lee',
        nextMobileNumber: '8888888888',
        nextDateOfBirthYmd: '1995-04-12',
        nextCountry: 'canada',
        nextCity: '',
      );
      expect(partial.keys.toSet(), {'mobileNumber', 'country'});
      expect(partial['mobileNumber'], '8888888888');
      expect(partial['country'], 'canada');
    });

    test('12/13. reopen + logout/login persistence via local flatten', () {
      final profile = V2AccountProfile.fromJson({
        'id': 'u1',
        'username': 'nova',
        'firstName': 'Nova',
        'lastName': 'Lee',
        'email': 'nova@example.com',
        'dateOfBirth': '1995-04-12',
        'mobileNumber': '9999999999',
        'country': 'india',
      });
      final local = profile.toLocalUserData(null);
      expect(local['nickName'], 'nova');
      expect(local['secondName'], 'Lee');
      expect(local['personalDetails']['country'], 'india');
      expect(local['dateOfBirth'], '1995-04-12');
      expect(local['mobileNumber'], '9999999999');

      // Rehydrate as after logout/login bootstrap from stored userData keys.
      final restored = V2AccountProfile.fromJson({
        'id': local['_id'],
        'nickName': local['nickName'],
        'firstName': local['firstName'],
        'secondName': local['secondName'],
        'email': local['email'],
        'dateOfBirth': local['dateOfBirth'],
        'personalDetails': local['personalDetails'],
      });
      expect(restored.username, 'nova');
      expect(restored.lastName, 'Lee');
      expect(restored.dateOfBirth, '1995-04-12');
      expect(restored.country, 'india');
      expect(restored.mobileNumber, '9999999999');
    });

    test('14/15. countries use name+label; alphabetical; selection restored', () {
      final countries = V2RegionOption.parseList({
        'data': {
          'countries': [
            {'name': 'usa', 'label': 'Usa'},
            {'name': 'india', 'label': 'India'},
            {'name': 'canada', 'label': 'Canada'},
          ],
        },
      })
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      expect(countries.map((c) => c.slug).toList(), ['canada', 'india', 'usa']);
      expect(countries.map((c) => c.name).toList(), ['Canada', 'India', 'Usa']);
      expect(countries.any((c) => c.slug == 'india'), isTrue);
    });

    test('16/17. DOB and mobile persistence mapping', () {
      final profile = V2AccountProfile.fromJson({
        'id': 'u1',
        'username': 'nova',
        'firstName': 'Nova',
        'lastName': 'Lee',
        'email': 'a@b.c',
        'dateOfBirth': '1995-04-12T00:00:00.000Z',
        'mobileNumber': '9999999999',
      });
      expect(profile.dateOfBirth, '1995-04-12');
      final patch = profile.changedPatchBody(
        nextUsername: 'nova',
        nextFirstName: 'Nova',
        nextLastName: 'Lee',
        nextMobileNumber: '8888888888',
        nextDateOfBirthYmd: '1990-01-02',
        nextCountry: '',
        nextCity: '',
      );
      expect(patch['dateOfBirth'], '1990-01-02');
      expect(patch['mobileNumber'], '8888888888');
    });

    test('18. validation/API failure handling + duplicate Save blocked',
        () async {
      final controller = V2AccountController(api: _FakeAccountApi());
      await controller.load();
      expect(controller.state.profile?.username, 'seed');

      final invalid = await controller.save(
        username: '',
        firstName: 'Nova',
        lastName: 'Lee',
        mobileNumber: 'bad',
        dateOfBirthYmd: '1995-04-12',
        country: 'india',
      );
      expect(invalid, isFalse);
      expect(controller.state.phase, V2AccountPhase.validationError);
      expect(controller.state.fieldErrors.containsKey('username'), isTrue);

      final api = _FakeAccountApi(delayMs: 40);
      final slow = V2AccountController(api: api);
      await slow.load();
      final first = slow.save(
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        mobileNumber: '9999999999',
        dateOfBirthYmd: '1995-04-12',
        country: 'india',
      );
      final second = slow.save(
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        mobileNumber: '9999999999',
        dateOfBirthYmd: '1995-04-12',
        country: 'india',
      );
      final results = await Future.wait([first, second]);
      expect(results.where((ok) => ok).length, 1);
      expect(api.patchCount, 1);

      final failing = V2AccountController(api: _FakeAccountApi(failPatch: true));
      await failing.load();
      final failed = await failing.save(
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        mobileNumber: '9999999999',
        dateOfBirthYmd: '1995-04-12',
        country: 'canada',
      );
      expect(failed, isFalse);
      expect(failing.state.phase, V2AccountPhase.apiError);
      expect(failing.state.profile?.username, 'seed');
    });
  });
}

class _FakeAccountApi extends V2AccountApi {
  _FakeAccountApi({this.failPatch = false, this.delayMs = 0});

  final bool failPatch;
  final int delayMs;
  int patchCount = 0;
  V2AccountProfile _profile = const V2AccountProfile(
    id: 'u1',
    username: 'seed',
    firstName: 'Seed',
    lastName: 'User',
    email: 'seed@example.com',
    country: 'india',
  );

  @override
  Future<V2AccountProfile> fetchProfile() async => _profile;

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    patchCount++;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (failPatch) throw V2AccountException('save failed');
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
        V2RegionOption(slug: 'usa', name: 'United States'),
        V2RegionOption(slug: 'canada', name: 'Canada'),
      ];
}
