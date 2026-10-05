import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/api_service.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/search/data/search_repository.dart';
import 'package:newson/features/search/domain/search_session.dart';
import 'package:newson/features/search/presentation/news_search_controller.dart';
import 'package:newson/features/search/presentation/v2_search_tab.dart';
import 'package:newson/providers/bookmark_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

Map<String, dynamic> _item(
  String id,
  String title,
  String lang, [
  String? district,
]) =>
    {
      '_id': id,
      'title': title,
      'language': lang,
      'detectedDistrict': district,
    };

/// Mirrors `GET /api/v2/search`: `q` matches titles, `language` and
/// `country`/`state`/`district` filter only when sent, `hasNextPage` comes
/// from the remaining matches.
List<Map<String, dynamic>> _corpus() => [
      for (var i = 0; i < 3; i++)
        _item('ta-trump-$i', 'டிரம்ப் Trump $i', 'ta'),
      for (var i = 0; i < 2; i++) _item('ta-only-$i', 'டிரம்ப் வரி $i', 'ta'),
      _item('en-madurai', 'Trump rally Madurai', 'en', 'Madurai'),
      for (var i = 0; i < 25; i++)
        _item('en-trump-$i', 'Trump tariffs $i', 'en'),
      for (var i = 0; i < 2; i++) _item('en-apple-$i', 'Apple launch $i', 'en'),
    ];

class _FakeSearchBackend implements ApiService {
  _FakeSearchBackend([List<Map<String, dynamic>>? corpus])
      : corpus = corpus ?? _corpus();

  final List<Map<String, dynamic>> corpus;
  final List<Map<String, String>> requests = [];

  /// Overrides the computed `hasNextPage` when set.
  bool? hasNextPage;

  /// Holds the response of the request with this 1-based index.
  final Map<int, Completer<void>> holds = {};

  @override
  Future<ApiResponse> getByPath(
    String relativeOrAbsolutePath, {
    Map<String, String>? headers,
    String? bearerToken,
    Map<String, String>? queryParameters,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    expect(relativeOrAbsolutePath, SearchRepository.path);
    expect(useV2Host, isTrue);
    final p = Map<String, String>.of(queryParameters!);
    requests.add(p);
    final hold = holds[requests.length];
    if (hold != null) await hold.future;

    final q = p['q']!.toLowerCase();
    final matched = [
      for (final it in corpus)
        if ((it['title'] as String).toLowerCase().contains(q) &&
            (p['language'] == null || it['language'] == p['language']) &&
            (p['district'] == null || it['detectedDistrict'] == p['district']))
          it,
    ];
    final page = int.parse(p['page']!);
    final limit = int.parse(p['limit']!);
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, matched.length);
    return ApiResponse(
      success: true,
      data: {
        'success': true,
        'data': {
          'items': start >= matched.length ? [] : matched.sublist(start, end),
          'page': page,
          'limit': limit,
          'hasNextPage': hasNextPage ?? end < matched.length,
        },
      },
      error: null,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('Unexpected ApiService call: ${invocation.memberName}');
}

/// Stand-in for the Home tab's language and region. Search never reads it.
class _HomeState {
  String language = 'ta';
  String? district;
}

NewsSearchController _controller(_FakeSearchBackend backend) =>
    NewsSearchController(repository: SearchRepository(apiService: backend));

Set<String?> _languages(NewsSearchController c) =>
    c.state.results.map((a) => a.language).toSet();

const _regionKeys = ['country', 'state', 'district', 'region', 'city'];

void main() {
  ensureTestBinding();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('search feature never reads the Home language or Home region', () {
    for (final f in Directory('lib/features/search')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('language_provider.dart')), reason: f.path);
      expect(src, isNot(contains('region_provider.dart')), reason: f.path);
      expect(src, isNot(contains('appliedRegion')), reason: f.path);
      expect(src, isNot(contains('newsLanguageCode')), reason: f.path);
    }
  });

  group('query parameters', () {
    test('All languages and no filters send only q/page/limit', () {
      expect(
        SearchRepository.queryParametersFor(query: 'Trump', page: 1, limit: 20),
        {'q': 'Trump', 'page': '1', 'limit': '20'},
      );
    });

    test('explicit language and district are sent with backend names', () {
      expect(
        SearchRepository.queryParametersFor(
          query: 'Trump',
          language: 'TA',
          filters: const SearchFilters(district: ' Madurai '),
          page: 2,
          limit: 20,
        ),
        {
          'q': 'Trump',
          'page': '2',
          'limit': '20',
          'language': 'ta',
          'district': 'Madurai',
        },
      );
    });
  });

  test('1. Home=Tamil, English topic returns English results', () async {
    final home = _HomeState()..language = 'ta';
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    await c.submit('tariffs');
    expect(home.language, 'ta');
    expect(backend.requests.single.containsKey('language'), isFalse);
    expect(c.state.results, isNotEmpty);
    expect(_languages(c), {'en'});
  });

  test('2. Home=English, Tamil topic returns Tamil results', () async {
    final home = _HomeState()..language = 'en';
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    await c.submit('டிரம்ப்');
    expect(home.language, 'en');
    expect(backend.requests.single.containsKey('language'), isFalse);
    expect(c.state.results, hasLength(5));
    expect(_languages(c), {'ta'});
  });

  test('3. Home=Tamil, no language selected searches all languages', () async {
    _HomeState().language = 'ta';
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    expect(c.state.searchLanguage, isNull);
    await c.submit('Trump');
    expect(backend.requests.single.containsKey('language'), isFalse);
    expect(_languages(c), {'en', 'ta'});
  });

  test('4. explicit English returns only English', () async {
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    await c.setSearchLanguage('en');
    expect(backend.requests, isEmpty, reason: 'no active search to re-run');
    await c.submit('Trump');
    expect(backend.requests.single['language'], 'en');
    expect(c.state.results, isNotEmpty);
    expect(_languages(c), {'en'});
  });

  test('5. explicit Tamil returns only Tamil', () async {
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    await c.setSearchLanguage('ta');
    await c.submit('Trump');
    expect(backend.requests.single['language'], 'ta');
    expect(c.state.results, hasLength(3));
    expect(_languages(c), {'ta'});
  });

  test('changing the search language re-runs the submitted query', () async {
    final backend = _FakeSearchBackend();
    final c = _controller(backend);
    await c.submit('Trump');
    await c.setSearchLanguage('ta');
    expect(backend.requests.last['q'], 'Trump');
    expect(backend.requests.last['language'], 'ta');
    expect(_languages(c), {'ta'});
    await c.setSearchLanguage(null);
    expect(backend.requests.last.containsKey('language'), isFalse);
    expect(_languages(c), {'en', 'ta'});
  });

  test(
    '6. Home=Tamil + saved region Madurai does not restrict "Trump"',
    () async {
      final home = _HomeState()
        ..language = 'ta'
        ..district = 'Madurai';
      final backend = _FakeSearchBackend();
      final c = _controller(backend);
      await c.submit('Trump');
      expect(home.district, 'Madurai');
      final sent = backend.requests.single;
      for (final k in _regionKeys) {
        expect(sent.containsKey(k), isFalse, reason: '$k must not be sent');
      }
      expect(sent.containsKey('language'), isFalse);
      expect(c.state.filters.isEmpty, isTrue);
      expect(
        c.state.results.where((a) => a.articleId != 'en-madurai'),
        isNotEmpty,
      );
    },
  );

  test(
    'explicit Search district filter is the only way to send a region',
    () async {
      final backend = _FakeSearchBackend();
      final c = _controller(backend);
      await c.submit('Trump');
      await c.setSearchFilters(const SearchFilters(district: 'Madurai'));
      expect(backend.requests.last['district'], 'Madurai');
      expect(backend.requests.last.containsKey('city'), isFalse);
      expect(c.state.results.map((a) => a.articleId), ['en-madurai']);
    },
  );

  group('7. Home language change mid-session', () {
    test('loadMore keeps "Trump" and All languages', () async {
      final home = _HomeState()..language = 'ta';
      final backend = _FakeSearchBackend();
      final c = _controller(backend);
      await c.submit('Trump');
      expect(c.state.hasMore, isTrue);
      home.language = 'en';
      await c.loadMore();
      final page2 = backend.requests.last;
      expect(page2['q'], 'Trump');
      expect(page2['page'], '2');
      expect(page2.containsKey('language'), isFalse);
    });

    test('loadMore keeps an explicit search language', () async {
      final home = _HomeState()..language = 'en';
      final backend = _FakeSearchBackend([
        for (var i = 0; i < 30; i++) _item('t$i', 'டிரம்ப் Trump $i', 'ta'),
      ]);
      final c = _controller(backend);
      await c.setSearchLanguage('ta');
      await c.submit('Trump');
      home.language = 'hi';
      await c.loadMore();
      expect(backend.requests.last['q'], 'Trump');
      expect(backend.requests.last['language'], 'ta');
      expect(c.state.results, hasLength(30));
    });
  });

  test(
    '8. typing "Apple" without submitting does not change loadMore',
    () async {
      final backend = _FakeSearchBackend();
      final c = _controller(backend);
      await c.submit('Trump');
      c.onQueryChanged('Apple');
      await Future<void>.delayed(
        NewsSearchController.suggestionDebounce +
            const Duration(milliseconds: 50),
      );
      expect(c.state.typedQuery, 'Apple');
      expect(c.state.submittedQuery, 'Trump');
      await c.loadMore();
      expect(backend.requests, hasLength(2));
      expect(backend.requests.last['q'], 'Trump');
      expect(backend.requests.last['page'], '2');
      expect(c.state.results.every((a) => a.title.contains('Trump')), isTrue);
    },
  );

  test('9. new submit during loadMore leaves pagination working', () async {
    final backend = _FakeSearchBackend([
      for (var i = 0; i < 25; i++) _item('trump-$i', 'Trump $i', 'en'),
      for (var i = 0; i < 25; i++) _item('modi-$i', 'Modi $i', 'en'),
    ]);
    final c = _controller(backend);
    await c.submit('Trump');
    final hold = backend.holds[2] = Completer<void>();
    final staleLoadMore = c.loadMore();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.status, SearchStatus.loadingMore);

    await c.submit('Modi');
    expect(c.state.hasMore, isTrue);
    hold.complete();
    await staleLoadMore;
    expect(
      c.state.results.every((a) => a.title.startsWith('Modi')),
      isTrue,
      reason: 'stale Trump page 2 must not be merged',
    );
    expect(c.state.page, 1);

    await c.loadMore();
    expect(backend.requests, hasLength(4));
    expect(backend.requests.last['q'], 'Modi');
    expect(backend.requests.last['page'], '2');
    expect(c.state.results, hasLength(25));
    expect(c.state.hasMore, isFalse);
  });

  test(
    'stale loadMore finishing after a newer loadMore keeps its guard',
    () async {
      final backend = _FakeSearchBackend([
        for (var i = 0; i < 60; i++) _item('a-$i', 'Alpha $i', 'en'),
      ]);
      final c = _controller(backend);
      await c.submit('Alpha');
      final staleHold = backend.holds[2] = Completer<void>();
      final stale = c.loadMore();
      await c.submit('Alpha');
      final currentHold = backend.holds[4] = Completer<void>();
      final current = c.loadMore();
      staleHold.complete();
      await stale;
      await c.loadMore();
      expect(backend.requests, hasLength(4), reason: 'no duplicate page 2');
      currentHold.complete();
      await current;
      expect(c.state.page, 2);
      expect(c.state.results, hasLength(40));
    },
  );

  group('hasNextPage is the source of truth', () {
    List<Map<String, dynamic>> twenty() => [
          for (var i = 0; i < 20; i++) _item('n$i', 'News $i', 'en'),
        ];

    test('10. 20 results + hasNextPage=false sends no next request', () async {
      final backend = _FakeSearchBackend(twenty())..hasNextPage = false;
      final c = _controller(backend);
      await c.submit('News');
      expect(c.state.results, hasLength(20));
      expect(c.state.hasMore, isFalse);
      await c.loadMore();
      expect(backend.requests, hasLength(1));
    });

    test('11. 20 results + hasNextPage=true requests the next page', () async {
      final backend = _FakeSearchBackend(twenty())..hasNextPage = true;
      final c = _controller(backend);
      await c.submit('News');
      expect(c.state.results, hasLength(20));
      expect(c.state.hasMore, isTrue);
      await c.loadMore();
      expect(backend.requests, hasLength(2));
      expect(backend.requests.last['page'], '2');
    });
  });

  test(
    '12. clear resets all search state and drops in-flight results',
    () async {
      final backend = _FakeSearchBackend();
      final c = _controller(backend);
      await c.setSearchLanguage('en');
      await c.setSearchFilters(const SearchFilters(district: 'Madurai'));
      await c.submit('Trump');
      await c.setSearchFilters(const SearchFilters());
      expect(c.state.hasMore, isTrue);
      final hold =
          backend.holds[backend.requests.length + 1] = Completer<void>();
      final pending = c.loadMore();
      await Future<void>.delayed(Duration.zero);

      c.clear();
      hold.complete();
      await pending;

      final s = c.state;
      expect(s.typedQuery, isEmpty);
      expect(s.submittedQuery, isEmpty);
      expect(s.searchLanguage, isNull);
      expect(s.filters.isEmpty, isTrue);
      expect(s.results, isEmpty);
      expect(s.page, 1);
      expect(s.hasMore, isFalse);
      expect(s.status, SearchStatus.idle);
      expect(s.errorCode, isNull);
      expect(s.recent, contains('Trump'), reason: 'history is kept');

      final sent = backend.requests.length;
      await c.loadMore();
      expect(backend.requests, hasLength(sent));
      await c.submit('Trump');
      expect(backend.requests.last.containsKey('language'), isFalse);
      expect(backend.requests.last.containsKey('district'), isFalse);
    },
  );

  group('V2SearchTab', () {
    Widget app(_FakeSearchBackend backend) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RemoteConfigProvider.forTest(
                RemoteConfigModel(primaryColor: '#E31E24'),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => BookmarkProvider(
                  isLoggedIn: () => false, prefetchAudio: (_) {}),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: V2SearchTab(
                  repository: SearchRepository(apiService: backend)),
            ),
          ),
        );

    bool selected(WidgetTester tester, String code) => tester
        .widget<ChoiceChip>(find.byKey(ValueKey('v2_search_language_$code')))
        .selected;

    testWidgets('language defaults to All; chip and clear drive the request', (
      tester,
    ) async {
      await tester.runAsync(
        () => DynamicLocalizationService().setLanguage('en', forceReload: true),
      );
      final backend = _FakeSearchBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(selected(tester, 'all'), isTrue);
      expect(selected(tester, 'ta'), isFalse);

      await tester.enterText(find.byType(TextField), 'Trump');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(backend.requests.single['q'], 'Trump');
      expect(backend.requests.single.containsKey('language'), isFalse);

      await tester.tap(find.byKey(const ValueKey('v2_search_language_ta')));
      await tester.pumpAndSettle();
      expect(selected(tester, 'ta'), isTrue);
      expect(backend.requests.last['language'], 'ta');
      expect(backend.requests.last['q'], 'Trump');

      await tester.tap(find.byKey(const ValueKey('v2_search_clear')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(selected(tester, 'all'), isTrue);
      expect(find.byKey(const ValueKey('v2_search_clear')), findsNothing);
    });
  });
}
