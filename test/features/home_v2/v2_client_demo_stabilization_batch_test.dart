import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';
import 'package:newson/core/utils/for_you_feed_layout.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/news_share_service.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';

NewsArticle _a(String id, {String title = 'Story'}) => NewsArticle(
      articleId: id,
      newsId: id,
      title: title,
      category: const ['top'],
      imageUrl: 'https://cdn.example/$id.jpg',
    );

void main() {
  group('Issue1 V2 share public URL', () {
    test('canonical share URL uses v2-api host + V2 articleId', () {
      final article = _a('6ab6a723261c38e362b06c7f', title: 'Floods');
      final id = NewsShareService.articleIdFor(article);
      expect(id, '6ab6a723261c38e362b06c7f');
      final uri = DeepLinkConstants.buildV2HttpsDeepLink(id!);
      expect(uri.host, DeepLinkConstants.v2HttpsHost);
      expect(uri.path, '/v2/news/6ab6a723261c38e362b06c7f');
      expect(
        NewsShareService.buildShareText(article, v2: true),
        contains(uri.toString()),
      );
    });

    test('does not emit V1 host for V2 shares', () {
      final text = NewsShareService.buildShareText(
        _a('6ab6a723261c38e362b06c88'),
        v2: true,
      );
      expect(text, contains('https://v2-api.newson.app/v2/news/'));
      expect(text, isNot(contains('https://api.newson.app/v2/news/')));
    });
  });

  group('Issue2 For You mosaic actions', () {
    test('layout partitions mosaic + spotlight', () {
      final items = List.generate(6, (i) => _a('id$i', title: 'T$i'));
      final blocks = ForYouFeedLayout.partition(items);
      expect(blocks, isNotEmpty);
      expect(blocks.first.mosaic, isNotEmpty);
      expect(blocks.first.spotlight, isNotEmpty);
    });

    test('V2 For You wires mosaic + spotlight bookmark/share handlers', () {
      final tab = File(
        'lib/features/for_you/presentation/v2_for_you_tab.dart',
      ).readAsStringSync();
      expect(tab, contains('onBookmark: (article, _) => _bookmark(article)'));
      expect(tab, contains('onShare: (article, _) => _share(article)'));
      expect(tab, contains('onSaveTap: () => _bookmark(article)'));
      expect(tab, contains('onShareTap: () => _share(article)'));
      expect(tab, contains('NewsShareService.shareArticle'));
      expect(tab, isNot(contains('getBookmarks')));
    });

    test('mosaic shows action row only when callbacks are provided', () {
      final mosaic = File(
        'lib/core/widgets/for_you_featured_mosaic.dart',
      ).readAsStringSync();
      expect(
        mosaic,
        contains('final showActions = onBookmark != null || onShare != null'),
      );
      expect(mosaic, contains('this.onBookmark'));
      expect(mosaic, contains('this.onShare'));
      expect(mosaic, contains('Icons.bookmark_border'));
      expect(mosaic, contains('Icons.share_outlined'));
    });
  });

  group('Issue3 Home/For You light theme scoping', () {
    test('local Theme override forces light under dark ambient', () {
      final light = ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
      );
      expect(light.brightness, Brightness.light);
      expect(ThemeData.dark().brightness, Brightness.dark);
    });

    testWidgets('dark ambient + light override keeps reading surface light',
        (tester) async {
      final light = ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              expect(Theme.of(context).brightness, Brightness.dark);
              return Theme(
                data: light,
                child: Builder(
                  builder: (inner) {
                    expect(Theme.of(inner).brightness, Brightness.light);
                    expect(
                      Theme.of(inner).scaffoldBackgroundColor,
                      const Color(0xFFFFF8F0),
                    );
                    return const Scaffold(body: Text('Home'));
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Search/Bookmarks stay on ambient dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              expect(Theme.of(context).brightness, Brightness.dark);
              return const Scaffold(body: Text('Search'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsOneWidget);
    });
  });

  group('Issue4 Account city', () {
    test('parses city from data.profile and personalDetails', () {
      final nested = V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'profile': {
            'id': 'u1',
            'username': 'Karthi',
            'firstName': 'K',
            'lastName': 'A',
            'email': 'k@e.com',
            'city': 'Chennai',
            'country': 'india',
          },
        },
      })!;
      expect(nested.city, 'Chennai');

      final personal = V2AccountProfile.fromJson({
        'id': 'u1',
        'username': 'x',
        'firstName': 'X',
        'lastName': 'Y',
        'email': 'x@y.z',
        'personalDetails': {'city': 'Coimbatore', 'country': 'india'},
      });
      expect(personal.city, 'Coimbatore');
    });

    test('changedPatchBody includes city when edited', () {
      const profile = V2AccountProfile(
        id: 'u1',
        username: 'nova',
        firstName: 'Nova',
        lastName: 'Lee',
        email: 'a@b.c',
        country: 'india',
        city: '',
      );
      final body = profile.changedPatchBody(
        nextUsername: 'nova',
        nextFirstName: 'Nova',
        nextLastName: 'Lee',
        nextMobileNumber: '',
        nextDateOfBirthYmd: null,
        nextCountry: 'india',
        nextCity: 'Madurai',
      );
      expect(body, {'city': 'Madurai'});
    });

    test('save + reopen preserves city via GET', () async {
      final api = _CityAccountApi();
      final controller = V2AccountController(api: api);
      await controller.load();
      expect(controller.state.profile?.city, isEmpty);

      final ok = await controller.save(
        username: 'Karthi',
        firstName: 'Karthj',
        lastName: 'Arjunan',
        mobileNumber: '8508748592',
        dateOfBirthYmd: '2001-01-01',
        country: 'india',
        city: 'Chennai',
      );
      expect(ok, isTrue);
      expect(controller.state.profile?.city, 'Chennai');

      final reopen = V2AccountController(api: api);
      await reopen.load();
      expect(reopen.state.profile?.city, 'Chennai');
      expect(reopen.state.profile?.country, 'india');
    });
  });
}

class _CityAccountApi extends V2AccountApi {
  Map<String, dynamic> _profileJson = {
    'id': 'u1',
    'email': 'karthi@example.com',
    'username': 'Karthi',
    'firstName': 'Karthj',
    'lastName': 'Arjunan',
    'dateOfBirth': '2001-01-01',
    'mobileNumber': '8508748592',
    'country': 'india',
    'city': '',
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
    return fetchProfile();
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [
        V2RegionOption(slug: 'india', name: 'India'),
      ];
}
