import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/screens/category_selection/category_selection_screen.dart';

/// Builds 18 active V2 categories. [duplicateBoundaryIds] simulates the V1
/// page1/page2 overlap (same `_id` for sports/health) that caused 16 unique.
List<Map<String, dynamic>> _eighteenCategories({
  bool includeInactive = true,
  bool duplicateBoundaryIds = false,
}) {
  const names = [
    'top',
    'world',
    'politics',
    'business',
    'technology',
    'science',
    'sports',
    'health',
    'entertainment',
    'lifestyle',
    'food',
    'travel',
    'environment',
    'education',
    'crime',
    'domestic',
    'other',
    'tourism',
  ];
  assert(names.length == 18);
  final createdAt = '2024-01-01T00:00:00.000Z';
  final list = <Map<String, dynamic>>[];
  for (var i = 0; i < names.length; i++) {
    final slug = names[i];
    // Identical createdAt across rows — V1 sort instability root cause.
    list.add({
      '_id': '${i.toString().padLeft(24, 'a')}',
      'name': slug,
      'slug': slug,
      'categoryName': slug,
      'isActive': true,
      'isDeleted': false,
      'createdAt': createdAt,
    });
  }
  if (duplicateBoundaryIds) {
    // Page-boundary duplicates: sports + health reappear with SAME ids.
    list.add(Map<String, dynamic>.from(list[6])); // sports
    list.add(Map<String, dynamic>.from(list[7])); // health
  }
  if (includeInactive) {
    list.add({
      '_id': 'bbbbbbbbbbbbbbbbbbbbbbbb',
      'name': 'archived',
      'slug': 'archived',
      'isActive': false,
      'isDeleted': false,
      'createdAt': createdAt,
    });
    list.add({
      '_id': 'cccccccccccccccccccccccc',
      'name': 'removed',
      'slug': 'removed',
      'isActive': true,
      'isDeleted': true,
      'createdAt': createdAt,
    });
  }
  return list;
}

void main() {
  group('V2 News Categories catalog (Issue 1)', () {
    test('parses all 18 active categories exactly once', () {
      final options = V2CategoryOption.parseList({
        'success': true,
        'data': {'categories': _eighteenCategories()},
      });
      expect(options, hasLength(18));
      final ids = options.map((o) => o.id).whereType<String>().toList();
      expect(ids.toSet(), hasLength(18));
      expect(options.any((o) => o.slug == 'archived'), isFalse);
      expect(options.any((o) => o.slug == 'removed'), isFalse);
    });

    test('identical createdAt does not drop categories (full V2 catalog)', () {
      final raw = _eighteenCategories();
      final stamps = raw
          .where((e) => e['isActive'] == true && e['isDeleted'] != true)
          .map((e) => e['createdAt'])
          .toSet();
      expect(stamps, hasLength(1));

      final options = V2CategoryOption.parseList({
        'data': {'categories': raw},
      });
      expect(options, hasLength(18));
    });

    test('page-boundary duplicate ids collapse to 18 unique (not 16 via miss)', () {
      // V1 bug shape: 20 rows with 2 duplicate ids → unique should still be 18.
      final raw = _eighteenCategories(duplicateBoundaryIds: true);
      expect(raw.where((e) => e['isActive'] == true && e['isDeleted'] != true),
          hasLength(20));

      final options = V2CategoryOption.parseList({
        'data': {'categories': raw},
      });
      expect(options, hasLength(18));
      final ids = options.map((o) => o.id).toSet();
      expect(ids, hasLength(18));
    });

    test('maps to CategoryModel UI list without empty ids', () {
      final options = V2CategoryOption.parseList({
        'data': {'categories': _eighteenCategories(includeInactive: false)},
      });
      final models = options.map(categoryModelFromV2Option).toList();
      expect(models, hasLength(18));
      expect(models.every((m) => m.id.isNotEmpty), isTrue);
      expect(models.every((m) => m.isActive && !m.isDeleted), isTrue);
      expect(models.map((m) => m.id).toSet(), hasLength(18));
    });

    test('repeated catalog parse replace semantics stay at 18 (no append growth)', () {
      final payload = {
        'data': {'categories': _eighteenCategories(includeInactive: false)},
      };
      final first = V2CategoryOption.parseList(payload)
          .map(categoryModelFromV2Option)
          .toList();
      final second = V2CategoryOption.parseList(payload)
          .map(categoryModelFromV2Option)
          .toList();
      // UI path assigns `_categories = models` (replace), never addAll on V2.
      final replaced = second; // simulates setState replace
      expect(first, hasLength(18));
      expect(replaced, hasLength(18));
      expect(replaced.map((m) => m.id).toSet(), hasLength(18));
    });
  });

  group('V2 Account Settings data.profile (Issue 2)', () {
    test('GET data.profile parsing hydrates all fields', () {
      final profile = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'profile': {
            'id': 'u1',
            'email': 'karthi@example.com',
            'username': 'Karthi',
            'firstName': 'Karthj',
            'lastName': 'Arjunan',
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
      expect(profile.email, 'karthi@example.com');
      expect(profile.country, ''); // absent in payload — not fabricated
    });

    test('flat data fallback still works', () {
      final profile = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'id': 'u1',
          'username': 'nova',
          'firstName': 'Nova',
          'lastName': 'Lee',
          'email': 'n@e.com',
          'country': 'india',
        },
      })!;
      expect(profile.username, 'nova');
      expect(profile.country, 'india');
    });

    test('partial/null fields are safe empty strings', () {
      final profile = V2AccountProfile.parseResponse({
        'data': {
          'profile': {
            'id': 'u2',
            'email': 'a@b.c',
            'username': null,
            'firstName': '',
            'lastName': null,
            'mobileNumber': null,
            'dateOfBirth': null,
          },
        },
      })!;
      expect(profile.username, '');
      expect(profile.firstName, '');
      expect(profile.lastName, '');
      expect(profile.mobileNumber, '');
      expect(profile.dateOfBirth, isNull);
      expect(profile.country, '');
    });

    test('country present when returned by profile endpoint', () {
      final profile = V2AccountProfile.parseResponse({
        'data': {
          'profile': {
            'id': 'u1',
            'username': 'x',
            'firstName': 'X',
            'lastName': 'Y',
            'email': 'x@y.z',
            'country': 'india',
          },
        },
      })!;
      expect(profile.country, 'india');
    });

    test('country absent is empty — not invented', () {
      final profile = V2AccountProfile.parseResponse({
        'data': {
          'profile': {
            'id': 'u1',
            'username': 'x',
            'firstName': 'X',
            'lastName': 'Y',
            'email': 'x@y.z',
          },
        },
      })!;
      expect(profile.country, isEmpty);
    });

    test('controller load + save + GET + reopen + logout/login', () async {
      final api = _NestedProfileAccountApi();
      final controller = V2AccountController(api: api);
      await controller.load();
      expect(controller.state.phase, V2AccountPhase.loaded);
      expect(controller.state.profile?.username, 'Karthi');
      expect(controller.state.profile?.firstName, 'Karthj');
      expect(controller.state.profile?.mobileNumber, '8508748592');
      expect(controller.state.profile?.country, isEmpty);

      final ok = await controller.save(
        username: 'Karthi2',
        firstName: 'Karthj',
        lastName: 'Arjunan',
        mobileNumber: '8508748592',
        dateOfBirthYmd: '2001-01-01',
        country: null,
      );
      expect(ok, isTrue);
      expect(api.patchCount, 1);
      expect(api.getCount, greaterThanOrEqualTo(2)); // load + post-PATCH GET
      expect(controller.state.profile?.username, 'Karthi2');

      // Reopen page → fresh controller GET
      final reopen = V2AccountController(api: api);
      await reopen.load();
      expect(reopen.state.profile?.username, 'Karthi2');
      expect(reopen.state.profile?.lastName, 'Arjunan');

      // Logout/login → new controller, same API source of truth
      final afterLogin = V2AccountController(api: api);
      await afterLogin.load();
      expect(afterLogin.state.profile?.username, 'Karthi2');
      expect(afterLogin.state.profile?.dateOfBirth, '2001-01-01');
    });

    test('wrong flat parse of nested envelope would empty fields', () {
      // Documents the prior bug: treating {profile:{...}} as the profile map.
      final nestedOnly = {
        'profile': {
          'username': 'Karthi',
          'firstName': 'Karthj',
          'lastName': 'Arjunan',
          'email': 'k@e.com',
          'id': 'u1',
        },
      };
      final broken = V2AccountProfile.fromJson(nestedOnly);
      expect(broken.username, isEmpty);

      final fixed = V2AccountProfile.parseResponse({
        'success': true,
        'data': nestedOnly,
      })!;
      expect(fixed.username, 'Karthi');
      expect(fixed.firstName, 'Karthj');
    });
  });
}

class _NestedProfileAccountApi extends V2AccountApi {
  int patchCount = 0;
  int getCount = 0;

  Map<String, dynamic> _profileJson = {
    'id': 'u1',
    'email': 'karthi@example.com',
    'username': 'Karthi',
    'firstName': 'Karthj',
    'lastName': 'Arjunan',
    'dateOfBirth': '2001-01-01',
    'mobileNumber': '8508748592',
  };

  @override
  Future<V2AccountProfile> fetchProfile() async {
    getCount++;
    // Mirror real GET envelope: { success, data: { profile } }
    return V2AccountProfile.parseResponse({
      'success': true,
      'data': {'profile': Map<String, dynamic>.from(_profileJson)},
    })!;
  }

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    patchCount++;
    _profileJson = {
      ..._profileJson,
      ...body,
    };
    return V2AccountProfile.parseResponse({
      'success': true,
      'data': {'profile': Map<String, dynamic>.from(_profileJson)},
    })!;
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [];
}
