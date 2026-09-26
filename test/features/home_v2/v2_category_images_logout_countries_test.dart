import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/account/presentation/v2_account_settings_screen.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:newson/screens/category_selection/category_selection_screen.dart';
import 'package:provider/provider.dart';

List<Map<String, dynamic>> _nCategories(
  int count, {
  bool includeInactive = false,
  bool withMedia = true,
}) {
  final list = <Map<String, dynamic>>[];
  for (var i = 0; i < count; i++) {
    final slug = 'cat-$i';
    list.add({
      '_id': i.toRadixString(16).padLeft(24, 'a'),
      'name': slug,
      'slug': slug,
      'categoryName': 'Category $i',
      'isActive': true,
      'isDeleted': false,
      if (withMedia && i % 3 != 2)
        'media': {
          'url': i.isEven
              ? 'https://cdn.example/$slug.png'
              : 'categories/$slug.png',
          'type': 'image',
        },
    });
  }
  if (includeInactive) {
    list.add({
      '_id': 'bbbbbbbbbbbbbbbbbbbbbbbb',
      'name': 'archived',
      'slug': 'archived',
      'isActive': false,
      'isDeleted': false,
    });
    list.add({
      '_id': 'cccccccccccccccccccccccc',
      'name': 'removed',
      'slug': 'removed',
      'isActive': true,
      'isDeleted': true,
    });
  }
  return list;
}

void main() {
  group('V2 category images + dynamic catalog', () {
    test('parses media.url absolute and relative with image base', () {
      final options = V2CategoryOption.parseList(
        {
          'data': {
            'categories': [
              {
                'id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
                'name': 'sports',
                'slug': 'sports',
                'media': {'url': 'https://cdn.example/sports.png', 'type': 'image'},
              },
              {
                'id': 'bbbbbbbbbbbbbbbbbbbbbbbb',
                'name': 'health',
                'slug': 'health',
                'media': {'url': 'categories/health.png', 'type': 'image'},
              },
              {
                'id': 'cccccccccccccccccccccccc',
                'name': 'other',
                'slug': 'other',
              },
            ],
          },
        },
        imageBaseUrl: 'https://images.newson.app/',
      );

      expect(options, hasLength(3));
      expect(options[0].imageUrl, 'https://cdn.example/sports.png');
      expect(options[0].mediaUrl, 'https://cdn.example/sports.png');
      expect(options[0].mediaType, 'image');
      expect(options[1].imageUrl, 'https://images.newson.app/categories/health.png');
      expect(options[1].mediaUrl, 'categories/health.png');
      expect(options[1].mediaType, 'image');
      expect(options[2].imageUrl, isNull);
      expect(options[2].mediaUrl, isNull);
      expect(options[2].mediaType, isNull);

      final models = options.map(categoryModelFromV2Option).toList();
      expect(models[0].imageUrl, 'https://cdn.example/sports.png');
      expect(models[1].imageUrl, 'https://images.newson.app/categories/health.png');
      expect(models[2].imageUrl, isNull);
    });

    test('null/missing image does not throw', () {
      expect(
        () => resolveCategoryImageUrl(mediaUrl: null, imageBaseUrl: 'https://x'),
        returnsNormally,
      );
      expect(resolveCategoryImageUrl(mediaUrl: '', imageBaseUrl: 'https://x'), isNull);
      expect(categoryMediaFromJson({'media': null}), isNull);
      expect(categoryMediaUrlFromJson({'media': null}), isNull);
    });

    test('all returned categories preserve image metadata when present', () {
      final options = V2CategoryOption.parseList(
        {
          'data': {
            'categories': _nCategories(18, withMedia: true),
          },
        },
        imageBaseUrl: 'https://img.test',
      );
      expect(options, hasLength(18));
      final withImage = options.where((o) => o.imageUrl != null).length;
      final without = options.where((o) => o.imageUrl == null).length;
      expect(withImage, greaterThan(0));
      expect(without, greaterThan(0));
      expect(withImage + without, 18);
    });

    test('dynamic counts: 18, 19, 25 — not capped; inactive excluded', () {
      for (final n in [18, 19, 25]) {
        final options = V2CategoryOption.parseList({
          'data': {
            'categories': _nCategories(n, includeInactive: true),
          },
        });
        expect(options, hasLength(n), reason: 'expected $n active categories');
        expect(options.any((o) => o.slug == 'archived'), isFalse);
        expect(options.any((o) => o.slug == 'removed'), isFalse);
        final models = options.map(categoryModelFromV2Option).toList();
        expect(models, hasLength(n));
        expect(models.map((m) => m.id).toSet(), hasLength(n));
      }
    });

    test('resolveCategoryImageUrl path parsing', () {
      expect(
        resolveCategoryImageUrl(
          mediaUrl: 'https://a.com/x.png',
          imageBaseUrl: 'https://base',
        ),
        'https://a.com/x.png',
      );
      expect(
        resolveCategoryImageUrl(
          mediaUrl: '/rel/path.png',
          imageBaseUrl: 'https://base/',
        ),
        'https://base/rel/path.png',
      );
      // Relative without base cannot load — safe null for UI fallback.
      expect(
        resolveCategoryImageUrl(mediaUrl: 'rel.png', imageBaseUrl: null),
        isNull,
      );
    });
  });

  group('V2 countries parsing', () {
    test('maps non-empty countries list from API envelope', () {
      final countries = V2RegionOption.parseList({
        'success': true,
        'data': {
          'countries': [
            {'name': 'india', 'label': 'India'},
            {'name': 'united states', 'label': 'United States'},
          ],
        },
      });
      expect(countries, hasLength(2));
      expect(countries.map((c) => c.slug).toList(), ['india', 'united states']);
      expect(countries.map((c) => c.name).toList(), ['India', 'United States']);
    });

    test('exact V2 countries contract {name,label} populates picker values', () {
      final countries = V2RegionOption.parseList({
        'success': true,
        'data': {
          'countries': [
            {'name': 'india', 'label': 'India'},
            {'name': 'united arab emirates', 'label': 'United Arab Emirates'},
          ],
        },
      });
      expect(countries.map((c) => c.slug).toList(), [
        'india',
        'united arab emirates',
      ]);
      expect(countries.map((c) => c.name).toList(), [
        'India',
        'United Arab Emirates',
      ]);
    });

    test('empty database produces safe empty state', () {
      final countries = V2RegionOption.parseList({
        'success': true,
        'data': {'countries': []},
      });
      expect(countries, isEmpty);
    });

    test('no hardcoded country list in parser', () {
      // Parser only returns what the payload contains.
      final countries = V2RegionOption.parseList({
        'data': {
          'countries': [
            {'name': 'bhutan', 'label': 'Bhutan'},
          ],
        },
      });
      expect(countries, hasLength(1));
      expect(countries.single.slug, 'bhutan');
    });

    test('selected country survives profile reload', () async {
      final api = _AccountApiWithCountries();
      final controller = V2AccountController(api: api);
      await controller.load();
      expect(controller.state.profile?.country, 'india');
      await controller.loadCountries();
      expect(controller.countries.any((c) => c.slug == 'india'), isTrue);

      final ok = await controller.save(
        username: 'Karthi',
        firstName: 'Karthj',
        lastName: 'Arjunan',
        mobileNumber: '8508748592',
        dateOfBirthYmd: '2001-01-01',
        country: 'india',
      );
      expect(ok, isTrue);

      final reopen = V2AccountController(api: api);
      await reopen.load();
      expect(reopen.state.profile?.country, 'india');
    });
  });

  group('V2 Account Settings logout', () {
    test('logout clears session via controller', () async {
      final api = _AccountApiWithCountries();
      final controller = V2AccountController(api: api);
      await controller.load();
      expect(controller.state.hasProfile, isTrue);
      await controller.logout();
      expect(api.sessionCleared, isTrue);
      expect(controller.state.hasProfile, isFalse);
      expect(controller.state.profile, isNull);
    });

    testWidgets('Logout button visible; confirm clears session and opens Auth',
        (tester) async {
      final api = _AccountApiWithCountries();
      final controller = V2AccountController(api: api);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => RemoteConfigProvider.forTest(
              RemoteConfigModel(primaryColor: '#E31E24'),
            ),
            child: V2AccountSettingsScreen(
              controller: controller,
              authScreenBuilder: (_) => const Scaffold(
                key: Key('v2_auth_entry'),
                body: Text('Auth Entry'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2_account_logout')), findsOneWidget);
      expect(find.text('Logout'), findsWidgets);

      await tester.tap(find.byKey(const Key('v2_account_logout')));
      await tester.pumpAndSettle();

      expect(find.text('Yes'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(api.sessionCleared, isTrue);
      expect(find.byKey(const Key('v2_auth_entry')), findsOneWidget);
      expect(find.byType(V2AccountSettingsScreen), findsNothing);

      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(navigator.canPop(), isFalse);
    });
  });
}

class _AccountApiWithCountries extends V2AccountApi {
  bool sessionCleared = false;
  Map<String, dynamic> _profileJson = {
    'id': 'u1',
    'email': 'karthi@example.com',
    'username': 'Karthi',
    'firstName': 'Karthj',
    'lastName': 'Arjunan',
    'dateOfBirth': '2001-01-01',
    'mobileNumber': '8508748592',
    'country': 'india',
  };

  @override
  Future<V2AccountProfile> fetchProfile() async {
    return V2AccountProfile.parseResponse({
      'success': true,
      'data': {'profile': Map<String, dynamic>.from(_profileJson)},
    })!;
  }

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    _profileJson = {..._profileJson, ...body};
    return V2AccountProfile.parseResponse({
      'success': true,
      'data': {'profile': Map<String, dynamic>.from(_profileJson)},
    })!;
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [
        V2RegionOption(slug: 'india', name: 'India'),
        V2RegionOption(slug: 'united states', name: 'United States'),
      ];

  @override
  Future<void> clearSession() async {
    sessionCleared = true;
  }
}
