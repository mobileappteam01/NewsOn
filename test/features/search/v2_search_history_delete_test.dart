import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/search/data/recent_searches_store.dart';
import 'package:newson/features/search/data/search_repository.dart';
import 'package:newson/features/search/presentation/news_search_controller.dart';
import 'package:newson/features/search/presentation/v2_search_tab.dart';
import 'package:newson/providers/bookmark_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

const _prefsKey = 'v2_recent_searches';

Future<List<String>> _persisted() async =>
    (await SharedPreferences.getInstance()).getStringList(_prefsKey) ??
    const [];

NewsSearchController _controller({RecentSearchesStore? store}) =>
    NewsSearchController(
      repository: SearchRepository(
        searchFetcher: ({
          required query,
          required language,
          required filters,
          required page,
          required limit,
        }) async =>
            NewsResponse(status: 'ok', totalResults: 0, results: const []),
      ),
      recentStore: store,
    );

/// Store whose writes wait for [gate], to exercise add/remove ordering.
class _SlowStore extends RecentSearchesStore {
  Completer<void> gate = Completer<void>();

  @override
  Future<List<String>> add(String query) async {
    await gate.future;
    return super.add(query);
  }
}

void main() {
  ensureTestBinding();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecentSearchesStore', () {
    test('add keeps newest first and the existing case-insensitive dedupe',
        () async {
      final store = RecentSearchesStore();
      await store.add('Flood');
      await store.add('chennai');
      await store.add('flood');
      expect(await store.load(), ['flood', 'chennai']);
    });

    test('remove deletes only that term and persists', () async {
      final store = RecentSearchesStore();
      await store.add('one');
      await store.add('two');
      await store.add('three');
      final left = await store.remove('two');
      expect(left, ['three', 'one']);
      expect(await _persisted(), ['three', 'one']);
      // A fresh store (app restart) reads the same list.
      expect(await RecentSearchesStore().load(), ['three', 'one']);
    });

    test('remove of several terms persists each removal', () async {
      final store = RecentSearchesStore();
      for (final q in ['a1', 'b2', 'c3', 'd4']) {
        await store.add(q);
      }
      await Future.wait([store.remove('b2'), store.remove('d4')]);
      expect(await RecentSearchesStore().load(), ['c3', 'a1']);
    });

    test('clear persists an empty list', () async {
      final store = RecentSearchesStore();
      await store.add('one');
      await store.clear();
      expect(await _persisted(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_prefsKey), isNotNull);
      expect(await RecentSearchesStore().load(), isEmpty);
    });

    test('add racing a remove never writes the removed term back', () async {
      final store = RecentSearchesStore();
      await store.add('keep');
      await store.add('gone');
      await Future.wait([store.add('new'), store.remove('gone')]);
      expect(await store.load(), ['new', 'keep']);
    });
  });

  group('NewsSearchController recent history', () {
    test('removeRecent updates state at once and survives restart', () async {
      final c = _controller();
      await c.submit('flood');
      await c.submit('chennai');
      await c.submit('cricket');
      expect(c.state.recent, ['cricket', 'chennai', 'flood']);

      final pending = c.removeRecent('chennai');
      expect(c.state.recent, ['cricket', 'flood'], reason: 'immediate UI');
      await pending;
      expect(await _persisted(), ['cricket', 'flood']);

      final restarted = _controller();
      await restarted.bootstrap();
      expect(restarted.state.recent, ['cricket', 'flood']);
    });

    test('removing several terms quickly never restores one', () async {
      final c = _controller();
      for (final q in ['aaa', 'bbb', 'ccc', 'ddd']) {
        await c.submit(q);
      }
      final seen = <List<String>>[];
      c.addListener(() => seen.add(List.of(c.state.recent)));
      await Future.wait([c.removeRecent('bbb'), c.removeRecent('ddd')]);

      expect(c.state.recent, ['ccc', 'aaa']);
      expect(seen.any((l) => l.contains('bbb')), isFalse,
          reason: 'bbb never comes back once removed');
      // seen[0] is the optimistic bbb removal; from the ddd removal on,
      // neither term reappears.
      expect(seen.skip(1).any((l) => l.contains('ddd')), isFalse);
      expect(await _persisted(), ['ccc', 'aaa']);
    });

    test('clear all empties state and persistence, restart stays empty',
        () async {
      final c = _controller();
      await c.submit('flood');
      await c.submit('chennai');
      await c.clearRecent();
      expect(c.state.recent, isEmpty);
      expect(await _persisted(), isEmpty);

      final restarted = _controller();
      await restarted.bootstrap();
      expect(restarted.state.recent, isEmpty);
    });

    test('removing the last term leaves the empty state', () async {
      final c = _controller();
      await c.submit('flood');
      await c.removeRecent('flood');
      expect(c.state.recent, isEmpty);
      expect(c.localSuggestions(''), isEmpty);
    });

    test('bootstrap finishing after a delete does not restore it', () async {
      SharedPreferences.setMockInitialValues({
        _prefsKey: ['one', 'two'],
      });
      final c = _controller();
      await c.bootstrap();
      final reload = c.bootstrap();
      await c.removeRecent('one');
      await reload;
      expect(c.state.recent, ['two']);
    });

    test('in-flight submit save does not undo a later delete', () async {
      SharedPreferences.setMockInitialValues({
        _prefsKey: ['old', 'stay'],
      });
      final store = _SlowStore();
      final c = _controller(store: store);
      await c.bootstrap();
      final submit = c.submit('fresh');
      await Future<void>.delayed(Duration.zero);
      await c.removeRecent('old');
      store.gate.complete();
      await submit;
      await Future<void>.delayed(Duration.zero);
      expect(await _persisted(), ['fresh', 'stay']);
      expect(c.state.recent.contains('old'), isFalse);
    });
  });

  group('V2SearchTab recent chips', () {
    Widget app() => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(primaryColor: '#E31E24'),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => BookmarkProvider(
                isLoggedIn: () => false,
                prefetchAudio: (_) {},
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: V2SearchTab())),
        );

    Future<void> setLanguage(WidgetTester tester, String code) async {
      await tester.runAsync(
        () => DynamicLocalizationService().setLanguage(code, forceReload: true),
      );
    }

    tearDown(() async {
      await DynamicLocalizationService().setLanguage('en', forceReload: true);
    });

    testWidgets('each term has a delete button that removes only it',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        _prefsKey: ['flood', 'chennai'],
      });
      await setLanguage(tester, 'en');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('flood'), findsOneWidget);
      expect(find.text('chennai'), findsOneWidget);
      final delete = find.byTooltip('Remove flood from recent searches');
      expect(delete, findsOneWidget);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('flood'), findsNothing);
      expect(find.text('chennai'), findsOneWidget);
      expect(await tester.runAsync(_persisted), ['chennai']);
    });

    testWidgets('Clear all empties the list', (tester) async {
      SharedPreferences.setMockInitialValues({
        _prefsKey: ['flood', 'chennai'],
      });
      await setLanguage(tester, 'en');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('flood'), findsNothing);
      expect(find.text('chennai'), findsNothing);
      expect(find.text('Clear all'), findsNothing);
      expect(await tester.runAsync(_persisted), isEmpty);
    });

    const expected = {
      'ta': 'சமீபத்திய தேடல்களிலிருந்து flood ஐ அகற்று',
      'hi': 'हाल की खोजों से flood हटाएं',
      'ml': 'സമീപകാല തിരയലുകളിൽ നിന്ന് flood നീക്കം ചെയ്യുക',
      'te': 'ఇటీవలి శోధనల నుండి flood తొలగించండి',
      'kn': 'ಇತ್ತೀಚಿನ ಹುಡುಕಾಟಗಳಿಂದ flood ತೆಗೆದುಹಾಕಿ',
    };
    for (final entry in expected.entries) {
      testWidgets('delete label is localized (${entry.key})', (tester) async {
        SharedPreferences.setMockInitialValues({
          _prefsKey: ['flood'],
        });
        await setLanguage(tester, entry.key);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.byTooltip(entry.value), findsOneWidget);
      });
    }
  });
}
