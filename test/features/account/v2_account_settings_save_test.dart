import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/account/data/v2_account_api.dart';
import 'package:newson/features/account/domain/v2_account_profile.dart';
import 'package:newson/features/account/domain/v2_account_validation.dart';
import 'package:newson/features/account/presentation/v2_account_settings_screen.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

/// In-memory account backend. The server trims names, so the reloaded
/// profile can differ from what was typed.
class _FakeAccountApi extends V2AccountApi {
  _FakeAccountApi({String firstName = 'Karthik'})
      : _profile = {
          'id': 'u1',
          'email': 'karthik@example.com',
          'username': 'karthik',
          'firstName': firstName,
          'lastName': 'Arjunan',
          'dateOfBirth': '2001-01-01',
          'mobileNumber': '8508748592',
          'country': 'india',
        };

  Map<String, dynamic> _profile;
  int fetchCalls = 0;
  final patches = <Map<String, dynamic>>[];
  Object? patchError;

  V2AccountProfile _parse() => V2AccountProfile.parseResponse({
        'success': true,
        'data': {'profile': Map<String, dynamic>.from(_profile)},
      })!;

  @override
  Future<V2AccountProfile> fetchProfile() async {
    fetchCalls++;
    return _parse();
  }

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    patches.add(body);
    if (patchError != null) throw patchError!;
    _profile = {
      ..._profile,
      for (final e in body.entries)
        e.key: e.value is String ? (e.value as String).trim() : e.value,
    };
    return _parse();
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [
        V2RegionOption(slug: 'india', name: 'India'),
      ];

  @override
  Future<void> clearSession() async {}
}

Widget _app(V2AccountController controller) => MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => RemoteConfigProvider.forTest(
          RemoteConfigModel(primaryColor: '#E31E24'),
        ),
        child: V2AccountSettingsScreen(controller: controller),
      ),
    );

TextField _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key));

bool _hasFocus(WidgetTester tester, Key key) =>
    _field(tester, key).focusNode?.hasFocus ?? false;

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byKey(V2AccountSettingsScreen.editButtonKey));
  await tester.pumpAndSettle();
}

bool _fieldEnabled(WidgetTester tester, Key key) =>
    _field(tester, key).enabled ?? true;

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(V2AccountSettingsScreen.saveButtonKey));
  await tester.tap(find.byKey(V2AccountSettingsScreen.saveButtonKey));
  await tester.pumpAndSettle();
}

void main() {
  ensureTestBinding();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('V2AccountValidation', () {
    test('username needs 3+ characters after trim', () {
      expect(V2AccountValidation.username(''), V2AccountFieldError.required);
      expect(V2AccountValidation.username('   '), V2AccountFieldError.required);
      expect(V2AccountValidation.username('a'), V2AccountFieldError.tooShort);
      expect(V2AccountValidation.username('ab'), V2AccountFieldError.tooShort);
      expect(V2AccountValidation.username('  ab  '),
          V2AccountFieldError.tooShort);
      expect(V2AccountValidation.username('abc'), isNull);
      expect(V2AccountValidation.username('  abc  '), isNull);
    });

    test('first name needs 3+ characters after trim', () {
      expect(V2AccountValidation.firstName(''), V2AccountFieldError.required);
      expect(V2AccountValidation.firstName('J'), V2AccountFieldError.tooShort);
      expect(V2AccountValidation.firstName(' Jo '),
          V2AccountFieldError.tooShort);
      expect(V2AccountValidation.firstName('Joe'), isNull);
    });

    test('non-Latin names count visible characters, not code units', () {
      // கமலா = க · ம · லா (3 characters, 4 code units).
      expect(V2AccountValidation.firstName('கமலா'), isNull);
      // அனு = அ · னு (2 characters, 3 code units).
      expect(V2AccountValidation.firstName('அனு'),
          V2AccountFieldError.tooShort);
    });

    test('last name is optional', () {
      expect(V2AccountValidation.lastName(''), isNull);
      expect(V2AccountValidation.lastName('   '), isNull);
      expect(V2AccountValidation.lastName('A'), isNull);
    });

    test('placeholder username is rejected', () {
      expect(V2AccountValidation.username('v2 staging'),
          V2AccountFieldError.placeholder);
    });
  });

  group('V2AccountController.save', () {
    test('blocks 1-2 character username / first name without calling API',
        () async {
      final api = _FakeAccountApi();
      final c = V2AccountController(api: api);
      await c.load();
      for (final pair in [
        ['ab', 'Karthik'],
        ['a', 'Karthik'],
        ['karthik', 'Jo'],
        ['karthik', ' J '],
      ]) {
        final ok = await c.save(
          username: pair[0],
          firstName: pair[1],
          lastName: '',
          mobileNumber: '8508748592',
          dateOfBirthYmd: '2001-01-01',
          country: 'india',
        );
        expect(ok, isFalse, reason: '$pair');
        expect(c.state.phase, V2AccountPhase.validationError);
      }
      expect(api.patches, isEmpty);
    });

    test('empty last name is valid and saved', () async {
      final api = _FakeAccountApi();
      final c = V2AccountController(api: api);
      await c.load();
      final revision = c.saveRevision;
      final ok = await c.save(
        username: 'karthik',
        firstName: 'Karthik',
        lastName: '',
        mobileNumber: '8508748592',
        dateOfBirthYmd: '2001-01-01',
        country: 'india',
      );
      expect(ok, isTrue);
      expect(c.state.profile!.lastName, '');
      expect(c.saveRevision, revision + 1);
    });
  });

  group('V2AccountSettingsScreen', () {
    testWidgets('typing shows the min-length error live and clears it',
        (tester) async {
      final c = V2AccountController(api: _FakeAccountApi());
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), 'ab');
      await tester.pump();
      expect(find.text('Username must be at least 3 characters'),
          findsOneWidget);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), 'abc');
      await tester.pump();
      expect(find.text('Username must be at least 3 characters'), findsNothing);
    });

    testWidgets('leaving a short first name shows its error on focus loss',
        (tester) async {
      final c = V2AccountController(api: _FakeAccountApi(firstName: 'Jo'));
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);
      expect(find.text('First name must be at least 3 characters'),
          findsNothing);

      await tester.tap(find.byKey(V2AccountSettingsScreen.firstNameFieldKey));
      await tester.pump();
      await tester.tap(find.byKey(V2AccountSettingsScreen.lastNameFieldKey));
      await tester.pump();
      expect(find.text('First name must be at least 3 characters'),
          findsOneWidget);
    });

    testWidgets('Save with a 2-character username is blocked', (tester) async {
      final api = _FakeAccountApi();
      final c = V2AccountController(api: api);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), ' ab ');
      await _save(tester);

      expect(api.patches, isEmpty);
      expect(find.text('Username must be at least 3 characters'),
          findsOneWidget);
      expect(find.text('Please fix the highlighted fields'), findsOneWidget);
      expect(_field(tester, V2AccountSettingsScreen.usernameFieldKey)
          .controller!.text, ' ab ');
    });

    testWidgets(
        'successful save reloads, clears focus, recreates fields and confirms',
        (tester) async {
      final api = _FakeAccountApi();
      final c = V2AccountController(api: api);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.tap(find.byKey(V2AccountSettingsScreen.firstNameFieldKey));
      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), '  Karthi  ');
      await tester.pump();
      expect(_hasFocus(tester, V2AccountSettingsScreen.firstNameFieldKey),
          isTrue);
      final before =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;
      final fetchesBefore = api.fetchCalls;

      await _save(tester);

      expect(api.patches, hasLength(1));
      expect(api.fetchCalls, fetchesBefore + 1,
          reason: 'saved values come from a fresh GET');
      final after =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;
      expect(identical(before, after), isFalse,
          reason: 'controllers rebuilt from saved data');
      expect(after!.text, 'Karthi', reason: 'server value, not typed text');
      expect(_hasFocus(tester, V2AccountSettingsScreen.firstNameFieldKey),
          isFalse);
      expect(FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()));
      expect(tester.testTextInput.isVisible, isFalse,
          reason: 'keyboard dismissed');
      expect(c.isDirty, isFalse);
      expect(c.state.phase, V2AccountPhase.saved);
      expect(find.text('Account settings saved'), findsOneWidget);

      // Form is not stuck: it can be edited and saved again.
      await _edit(tester);
      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Karthikeyan');
      await tester.pump();
      expect(c.isDirty, isTrue);
      await _save(tester);
      expect(
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey)
              .controller!
              .text,
          'Karthikeyan');
    });

    testWidgets('failed save keeps the typed values and the dirty form',
        (tester) async {
      final api = _FakeAccountApi()..patchError = Exception('HTTP 500');
      final c = V2AccountController(api: api);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Karthikeyan');
      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.lastNameFieldKey), '');
      await tester.pump();
      final before =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;

      await _save(tester);

      expect(c.state.phase, V2AccountPhase.apiError);
      expect(c.isDirty, isTrue);
      final after =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;
      expect(identical(before, after), isTrue);
      expect(after!.text, 'Karthikeyan');
      expect(
          _field(tester, V2AccountSettingsScreen.lastNameFieldKey)
              .controller!
              .text,
          '');
      expect(find.text('Account settings saved'), findsNothing);
    });

    testWidgets('empty last name saves without an error', (tester) async {
      final api = _FakeAccountApi();
      final c = V2AccountController(api: api);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.lastNameFieldKey), '');
      await tester.pump();
      await _save(tester);

      expect(api.patches.single['lastName'], '');
      expect(c.state.phase, V2AccountPhase.saved);
      expect(
          _field(tester, V2AccountSettingsScreen.lastNameFieldKey)
              .decoration
              ?.errorText,
          isNull);
    });

    testWidgets('validation messages are localized (ta)', (tester) async {
      await tester.runAsync(
        () => DynamicLocalizationService().setLanguage('ta', forceReload: true),
      );
      addTearDown(() =>
          DynamicLocalizationService().setLanguage('en', forceReload: true));
      final c = V2AccountController(api: _FakeAccountApi());
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), 'ab');
      await tester.pump();
      expect(find.text('பயனர்பெயர் குறைந்தது 3 எழுத்துகள் இருக்க வேண்டும்'),
          findsOneWidget);
    });
  });

  group('V2AccountSettingsScreen view / edit mode', () {
    const fieldKeys = [
      V2AccountSettingsScreen.usernameFieldKey,
      V2AccountSettingsScreen.firstNameFieldKey,
      V2AccountSettingsScreen.lastNameFieldKey,
    ];
    final save = find.byKey(V2AccountSettingsScreen.saveButtonKey);
    final edit = find.byKey(V2AccountSettingsScreen.editButtonKey);

    Future<void> pumpScreen(WidgetTester tester, V2AccountApi api) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(V2AccountController(api: api)));
      await tester.pumpAndSettle();
    }

    void expectViewMode(WidgetTester tester) {
      expect(save, findsNothing, reason: 'Save hidden in view mode');
      expect(edit, findsOneWidget, reason: 'Edit icon is the entry point');
      for (final k in fieldKeys) {
        expect(_fieldEnabled(tester, k), isFalse, reason: '$k read-only');
      }
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('v2_account_dob')))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.byKey(const Key('v2_account_country')))
              .onPressed,
          isNull);
    }

    void expectEditMode(WidgetTester tester) {
      expect(save, findsOneWidget);
      expect(edit, findsNothing);
      for (final k in fieldKeys) {
        expect(_fieldEnabled(tester, k), isTrue, reason: '$k editable');
      }
    }

    testWidgets('opens in view mode with saved values and no Save button',
        (tester) async {
      final api = _FakeAccountApi();
      await pumpScreen(tester, api);

      expectViewMode(tester);
      expect(
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey)
              .controller!
              .text,
          'Karthik');
      expect(tester.widget<IconButton>(edit).tooltip, 'Edit profile');

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Changed');
      await tester.pump();
      expect(
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey)
              .controller!
              .text,
          'Karthik',
          reason: 'disabled fields ignore input');
    });

    testWidgets('Edit makes fields editable and shows Save', (tester) async {
      await pumpScreen(tester, _FakeAccountApi());
      final before =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;

      await _edit(tester);

      expectEditMode(tester);
      final after =
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey).controller;
      expect(identical(before, after), isTrue,
          reason: 'entering edit mode keeps the controllers');
      expect(after!.text, 'Karthik');
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('v2_account_dob')))
              .onPressed,
          isNotNull);
    });

    testWidgets('invalid Save shows errors and stays in edit mode',
        (tester) async {
      final api = _FakeAccountApi();
      await pumpScreen(tester, api);
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), 'ab');
      await _save(tester);

      expect(api.patches, isEmpty);
      expect(find.text('Username must be at least 3 characters'),
          findsOneWidget);
      expectEditMode(tester);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull,
          reason: 'Save still available after a validation error');
    });

    testWidgets('failed API save stays in edit mode', (tester) async {
      final api = _FakeAccountApi()..patchError = Exception('HTTP 500');
      await pumpScreen(tester, api);
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Karthikeyan');
      await _save(tester);

      expectEditMode(tester);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    });

    testWidgets(
        'valid Save updates, returns to view mode and survives reopening',
        (tester) async {
      final api = _FakeAccountApi();
      await pumpScreen(tester, api);
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Karthikeyan');
      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.usernameFieldKey), 'karthik_a');
      await _save(tester);

      expect(api.patches, hasLength(1));
      expect(find.text('Account settings saved'), findsOneWidget);
      expectViewMode(tester);
      expect(
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey)
              .controller!
              .text,
          'Karthikeyan');
      expect(
          _field(tester, V2AccountSettingsScreen.usernameFieldKey)
              .controller!
              .text,
          'karthik_a');

      // Close and reopen with a fresh screen/controller on the same backend.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(tester, api);

      expectViewMode(tester);
      expect(
          _field(tester, V2AccountSettingsScreen.firstNameFieldKey)
              .controller!
              .text,
          'Karthikeyan');
    });

    testWidgets('Save is ignored while a save is in flight', (tester) async {
      final api = _SlowAccountApi();
      await pumpScreen(tester, api);
      await _edit(tester);

      await tester.enterText(
          find.byKey(V2AccountSettingsScreen.firstNameFieldKey), 'Karthikeyan');
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.bySemanticsLabel('Save'), findsOneWidget);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();

      api.release();
      await tester.pumpAndSettle();
      expect(api.patches, hasLength(1));
      expectViewMode(tester);
    });
  });
}

class _SlowAccountApi extends _FakeAccountApi {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    await _gate.future;
    return super.patchProfile(body);
  }
}
