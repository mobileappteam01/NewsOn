import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/account/presentation/v2_account_settings_screen.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/providers/dynamic_language_provider.dart';
import 'package:newson/providers/language_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:newson/screens/drawer_widgets/application_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

const _languages = ['en', 'es', 'fr', 'hi', 'kn', 'ml', 'ta', 'te'];
const _firebaseLanguages = ['en', 'hi', 'kn', 'ml', 'ta', 'te'];

/// Values that are correctly identical to English in that language
/// (brand names, or words spelled the same).
const _sameAsEnglishAllowed = <String, Set<String>>{
  'appName': {'es', 'fr', 'hi', 'kn', 'ml', 'ta', 'te'},
  'v2NewsOnCut': {'es', 'fr', 'hi', 'kn', 'ml', 'ta', 'te'},
  'error': {'es'},
  'no': {'es'},
  'notifications': {'fr'},
  'menu': {'fr'},
  'version': {'fr'},
  'date': {'fr'},
  'v2FilterDate': {'fr'},
  'regionDistrict': {'fr'},
  'v2NotificationTitle': {'fr'},
};

/// Screens reachable from Application Settings and the side menu.
const _settingsUiFiles = [
  'lib/screens/drawer_widgets/application_settings.dart',
  'lib/screens/drawer_widgets/text_size_settings.dart',
  'lib/screens/drawer_widgets/appearance_settings.dart',
  'lib/screens/drawer_widgets/news_reading_settings.dart',
  'lib/screens/drawer_widgets/background_music_settings.dart',
  'lib/screens/drawer_widgets/privacy_policy.dart',
  'lib/screens/drawer_widgets/terms_and_conditions.dart',
  'lib/screens/drawer_widgets/contact_us.dart',
  'lib/core/widgets/language_selector_dialog.dart',
  'lib/core/widgets/app_drawer.dart',
  'lib/features/account/presentation/v2_account_settings_screen.dart',
  'lib/features/notifications/presentation/v2_notification_inbox_screen.dart',
];

/// Literal UI text that is intentionally not translated.
const _allowedLiterals = {
  'A-', // text size symbols
  'A+',
  'NEWS', // brand mark in the (unused) about dialog
  'ON',
  '© 2025 NewsOn. All rights reserved.',
};

Map<String, String> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

Map<String, Map<String, String>> _allLanguages() => {
      for (final code in _languages)
        code: _readJson('assets/languages/$code.json'),
    };

Set<String> _helperKeys() {
  final src = File('lib/core/utils/localization_helper.dart').readAsStringSync();
  return {
    for (final m in RegExp(r"key:\s*'(\w+)'").allMatches(src)) m.group(1)!,
    for (final m in RegExp(r"hasTranslation\('(\w+)'\)").allMatches(src))
      m.group(1)!,
  };
}

Set<String> _placeholders(String s) =>
    {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m.group(1)!};

/// Mirrors [DynamicLanguageProvider.setLanguageByCode] without the Hive
/// write, which needs platform channels.
class _TestDynamicLanguageProvider extends DynamicLanguageProvider {
  Future<void> switchTo(String code) async {
    await DynamicLocalizationService().setLanguage(code, forceReload: true);
    notifyListeners();
  }
}

class _FakeAccountApi extends V2AccountApi {
  @override
  Future<V2AccountProfile> fetchProfile() async =>
      V2AccountProfile.parseResponse({
        'success': true,
        'data': {
          'profile': {
            'id': 'u1',
            'email': 'user@example.com',
            'username': 'karthik',
            'firstName': 'Karthik',
            'lastName': '',
            'mobileNumber': '',
            'country': '',
          },
        },
      })!;

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [];
}

RemoteConfigProvider _config() => RemoteConfigProvider.forTest(
      RemoteConfigModel(primaryColor: '#E31E24', enableVoiceFeatures: true),
    );

Future<void> _setLanguage(WidgetTester tester, String code) => tester.runAsync(
      () => DynamicLocalizationService().setLanguage(code, forceReload: true),
    );

void main() {
  ensureTestBinding();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await DynamicLocalizationService().setLanguage('en', forceReload: true);
  });

  group('language files', () {
    final files = _allLanguages();
    final english = files['en']!;

    test('every LocalizationHelper key exists in every language', () {
      final keys = _helperKeys();
      expect(keys.length, greaterThan(300));
      for (final code in _languages) {
        final missing = [
          for (final k in keys)
            if ((files[code]![k] ?? '').trim().isEmpty) k,
        ];
        expect(missing, isEmpty, reason: '$code is missing $missing');
      }
    });

    test('all languages share the same key set', () {
      for (final code in _languages) {
        expect(files[code]!.keys.toSet(), english.keys.toSet(),
            reason: '$code key set differs from en');
      }
    });

    test('placeholders match English in every translation', () {
      for (final code in _languages) {
        for (final e in english.entries) {
          expect(_placeholders(files[code]![e.key]!), _placeholders(e.value),
              reason: '$code.${e.key}');
        }
      }
    });

    test('helper strings are translated, not copied from English', () {
      for (final key in _helperKeys()) {
        for (final code in _languages.where((c) => c != 'en')) {
          if (_sameAsEnglishAllowed[key]?.contains(code) ?? false) continue;
          expect(files[code]![key], isNot(english[key]),
              reason: '$code.$key is still English');
        }
      }
    });

    test('firebase_languages mirror the bundled assets', () {
      for (final code in _firebaseLanguages) {
        expect(_readJson('firebase_languages/$code.json'), files[code],
            reason: 'firebase_languages/$code.json is out of sync');
      }
    });
  });

  test('settings and side-menu screens have no hardcoded UI text', () {
    final literal = RegExp(
      r'''(?:\bText\(|labelText:|hintText:|helperText:|errorText:|tooltip:|semanticLabel:|\blabel:)\s*(?:const\s+)?(['"])((?:(?!\1).)*)\1''',
    );
    final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
    for (final path in _settingsUiFiles) {
      final src = File(path).readAsStringSync();
      final offenders = [
        for (final m in literal.allMatches(src))
          if (!_allowedLiterals.contains(m.group(2)) &&
              RegExp('[A-Za-z]')
                  .hasMatch(m.group(2)!.replaceAll(interpolation, '')))
            m.group(2),
      ];
      expect(offenders, isEmpty, reason: '$path has literal UI text');
    }
  });

  group('Application Settings', () {
    final files = _allLanguages();
    const keys = [
      'applicationSettings',
      'language',
      'textSize',
      'appearance',
      'newsReadingSettings',
      'backgroundMusic',
    ];

    for (final code in _languages) {
      testWidgets('renders every label in $code', (tester) async {
        await _setLanguage(tester, code);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => _config()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<DynamicLanguageProvider>(
              create: (_) => _TestDynamicLanguageProvider(),
            ),
          ],
          child: const MaterialApp(home: ApplicationSettings()),
        ));
        await tester.pump();

        for (final key in keys) {
          expect(find.text(files[code]![key]!), findsOneWidget,
              reason: '$code.$key');
          if (code != 'en' && files[code]![key] != files['en']![key]) {
            expect(find.text(files['en']![key]!), findsNothing,
                reason: '$code shows English for $key');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('switches language immediately without a restart',
        (tester) async {
      final provider = _TestDynamicLanguageProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => _config()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<DynamicLanguageProvider>.value(
            value: provider,
          ),
        ],
        child: const MaterialApp(home: ApplicationSettings()),
      ));
      await tester.pump();
      expect(find.text(files['en']!['applicationSettings']!), findsOneWidget);

      for (final code in ['ta', 'fr', 'ml', 'es', 'en']) {
        await tester.runAsync(() => provider.switchTo(code));
        await tester.pump();
        for (final key in keys) {
          expect(find.text(files[code]![key]!), findsOneWidget,
              reason: 'after switching to $code: $key');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language_code'), 'en');
    });

    test('selected language is persisted for the next launch', () async {
      await DynamicLocalizationService().setLanguage('ta', forceReload: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language_code'), 'ta');
      expect(DynamicLocalizationService().currentLanguageCode, 'ta');
    });
  });

  group('parameterized messages', () {
    final files = _allLanguages();

    for (final code in _languages) {
      testWidgets('fill placeholders in $code', (tester) async {
        await _setLanguage(tester, code);
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ));

        String expected(String key, Map<String, String> params) {
          var s = files[code]![key]!;
          params.forEach((k, v) => s = s.replaceAll('{$k}', v));
          return s;
        }

        expect(LocalizationHelper.appLanguageChangedTo(ctx, 'தமிழ்'),
            expected('appLanguageChangedTo', {'language': 'தமிழ்'}));
        expect(LocalizationHelper.newsLanguageChangedTo(ctx, 'हिन्दी'),
            expected('newsLanguageChangedTo', {'language': 'हिन्दी'}));
        expect(LocalizationHelper.error(ctx, 'x'),
            expected('error', {'error': 'x'}));
        expect(LocalizationHelper.errorLoadingNews(ctx, 'x'),
            expected('errorLoadingNews', {'error': 'x'}));
        expect(LocalizationHelper.sourceLabel(ctx, 'BBC'),
            expected('sourceLabel', {'source': 'BBC'}));
        expect(LocalizationHelper.categoriesSelectedCount(ctx, 2, 5),
            expected('categoriesSelectedCount',
                {'selected': '2', 'total': '5'}));
      });
    }
  });

  group('V2 Account Settings', () {
    final files = _allLanguages();
    const keys = [
      'v2AccountUsername',
      'v2AccountFirstName',
      'v2AccountLastName',
      'v2AccountMobileNumber',
      'v2AccountCity',
      'dateOfBirth',
      'regionCountry',
      'logout',
    ];

    for (final code in ['en', 'ta', 'fr', 'kn']) {
      testWidgets('form labels are localized in $code', (tester) async {
        tester.view.physicalSize = const Size(1080, 3200);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await _setLanguage(tester, code);
        final controller = V2AccountController(api: _FakeAccountApi());
        await tester.pumpWidget(MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => _config(),
            child: V2AccountSettingsScreen(controller: controller),
          ),
        ));
        await tester.pumpAndSettle();

        for (final key in keys) {
          expect(find.text(files[code]![key]!), findsWidgets,
              reason: '$code.$key');
        }
        expect(find.text(files[code]!['v2AccountSelectDate']!), findsOneWidget);
        expect(find.text(files[code]!['selectCountry']!), findsOneWidget);
        expect(find.byTooltip(files[code]!['v2AccountEdit']!), findsOneWidget);

        await tester.tap(find.byKey(V2AccountSettingsScreen.editButtonKey));
        await tester.pumpAndSettle();
        expect(find.text(files[code]!['save']!), findsWidgets,
            reason: '$code.save');
      });
    }
  });
}
