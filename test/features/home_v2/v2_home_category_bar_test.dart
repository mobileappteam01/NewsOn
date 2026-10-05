import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home_v2/data/v2_home_api.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_home_filter_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_home_category_bar.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_home_filter_sheet.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _article(String id) =>
    NewsArticle(articleId: id, newsId: id, title: 'Story $id');

String _id(String tag, int n) =>
    '${tag.codeUnitAt(0).toRadixString(16)}${n.toString().padLeft(22, '0')}';

class _FakeMetadata extends V2HomeMetadataApi {
  _FakeMetadata(this.catalog);

  final List<Map<String, dynamic>> catalog;
  bool failFirst = false;
  int categoryCalls = 0;

  @override
  Future<List<V2CategoryOption>> fetchCategories() async {
    categoryCalls++;
    if (failFirst) {
      failFirst = false;
      throw V2HomeException('offline', kind: V2HomeFailureKind.network);
    }
    return V2CategoryOption.parseList({'data': catalog});
  }

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [
        V2RegionOption(slug: 'india', name: 'India'),
      ];

  @override
  Future<List<V2RegionOption>> fetchStates(String country) async => const [];

  @override
  Future<List<V2RegionOption>> fetchCities({
    required String country,
    required String state,
  }) async =>
      const [];
}

const _catalog = [
  {'_id': 'aaaaaaaaaaaaaaaaaaaaaaa1', 'slug': 'politics', 'name': 'politics'},
  {'_id': 'aaaaaaaaaaaaaaaaaaaaaaa2', 'slug': 'sports', 'name': 'Sports'},
  {'_id': 'aaaaaaaaaaaaaaaaaaaaaaa3', 'slug': 'business', 'name': 'Business'},
];

typedef _Call = ({int page, HomeFilterState filter});

/// `GET /api/v2/home` stand-in: page N of whatever filter was requested.
class _FakeHome {
  final List<_Call> calls = [];
  final Map<String, Completer<void>> gates = {};
  final Set<String> failCategories = {};
  final Set<String> emptyCategories = {};
  bool hasMore = true;

  String _tag(HomeFilterState f) =>
      f.hasCategories ? (List.of(f.selectedCategorySlugs)..sort()).join('+') : 'all';

  Future<V2FeedPage> call({
    required int page,
    required int limit,
    required String language,
    required HomeFilterState filter,
  }) async {
    calls.add((page: page, filter: filter));
    final tag = _tag(filter);
    final gate = gates[tag];
    if (gate != null) await gate.future;
    if (failCategories.contains(tag)) {
      throw V2HomeException('offline', kind: V2HomeFailureKind.network);
    }
    if (emptyCategories.contains(tag)) {
      return V2FeedPage(articles: const [], page: page, hasMore: false);
    }
    return V2FeedPage(
      articles: [_article(_id(tag, page))],
      page: page,
      hasMore: hasMore,
    );
  }
}

class _Rig {
  _Rig({List<Map<String, dynamic>> catalog = _catalog})
      : metadata = _FakeMetadata(catalog) {
    filters = V2HomeFilterController(metadataApi: metadata);
    reader = V2ReaderController(
      newsLanguageCode: () => 'ta',
      appliedRegion: () => const SavedRegion(),
      homeFilter: () => filters.requestFilter,
      homeLoader: home.call,
    );
  }

  final _FakeMetadata metadata;
  final home = _FakeHome();
  late final V2HomeFilterController filters;
  late final V2ReaderController reader;

  /// Same wiring as `V2ReaderHome._onCategoryTapped` / `_onAllCategories`.
  Future<void> tap(String slug) {
    filters.toggleCategory(slug);
    return reader.refresh();
  }

  Future<void> tapAll() async {
    if (filters.clearCategories()) await reader.refresh();
  }

  Future<void> boot() async {
    await filters.syncSavedPreferences();
    await reader.loadInitial();
  }

  List<String> get ids => [for (final a in reader.state.articles) a.newsId!];
  _Call get last => home.calls.last;
  Map<String, String> query(_Call c) =>
      c.filter.toQueryParameters(language: 'ta', page: c.page, limit: 20);
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Widget _bar({
  required V2HomeFilterController filters,
  ThemeData? theme,
  double width = 390,
  double textScale = 1.0,
  void Function(String)? onToggle,
  VoidCallback? onAll,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ListenableBuilder(
              listenable: filters,
              builder: (context, _) => V2HomeCategoryBar(
                categories: filters.catalog,
                selectedSlugs: filters.committed.selectedCategorySlugs,
                pending: filters.catalogPending,
                failed: filters.catalogFailed,
                onToggle: onToggle ?? filters.toggleCategory,
                onSelectAll: onAll ?? () => filters.clearCategories(),
                onRetry: filters.reloadCatalog,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _selected(WidgetTester tester, String key) {
  final node = tester.getSemantics(find.byKey(ValueKey(key)));
  return node.getSemanticsData().flagsCollection.isSelected;
}

void main() {
  group('category row UI', () {
    testWidgets('categories come from the V2 catalog, with All first',
        (tester) async {
      final rig = _Rig();
      await rig.filters.syncSavedPreferences();
      await tester.pumpWidget(_bar(filters: rig.filters));

      expect(rig.metadata.categoryCalls, 1);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Politics'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Crime'), findsNothing);
      final allX = tester.getTopLeft(find.text('All')).dx;
      expect(allX, lessThan(tester.getTopLeft(find.text('Politics')).dx));
      expect(tester.getSize(find.byType(V2HomeCategoryBar)).height,
          V2HomeCategoryBar.height);
    });

    testWidgets('All is selected with no temporary categories', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = _Rig();
      await rig.filters.syncSavedPreferences();
      await tester.pumpWidget(_bar(filters: rig.filters));

      expect(_selected(tester, 'v2_category_all'), isTrue);
      expect(_selected(tester, 'v2_category_sports'), isFalse);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      handle.dispose();
    });

    testWidgets('multi-select toggle semantics are the same as the sheet had',
        (tester) async {
      final handle = tester.ensureSemantics();
      final rig = _Rig();
      await rig.filters.syncSavedPreferences();
      await tester.pumpWidget(_bar(filters: rig.filters, width: 700));

      await tester.tap(find.text('Sports'));
      await tester.pump();
      await tester.tap(find.text('Business'));
      await tester.pump();
      expect(rig.filters.committed.selectedCategorySlugs, ['sports', 'business']);
      expect(_selected(tester, 'v2_category_sports'), isTrue);
      expect(_selected(tester, 'v2_category_business'), isTrue);
      expect(_selected(tester, 'v2_category_all'), isFalse);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

      await tester.tap(find.text('Sports'));
      await tester.pump();
      expect(rig.filters.committed.selectedCategorySlugs, ['business']);

      await tester.tap(find.text('All'));
      await tester.pump();
      expect(rig.filters.committed.hasCategories, isFalse);
      expect(_selected(tester, 'v2_category_all'), isTrue);
      handle.dispose();
    });

    testWidgets('same height while loading, loaded and failed', (tester) async {
      final rig = _Rig();
      await tester.pumpWidget(_bar(filters: rig.filters));
      expect(find.byKey(const ValueKey('v2_category_placeholder')),
          findsOneWidget);
      final loadingHeight = tester.getSize(find.byType(V2HomeCategoryBar)).height;

      rig.metadata.failFirst = true;
      await tester.runAsync(rig.filters.syncSavedPreferences);
      await tester.pump();
      expect(rig.filters.catalogFailed, isTrue);
      expect(find.text('All'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_category_retry')), findsOneWidget);
      final failedHeight = tester.getSize(find.byType(V2HomeCategoryBar)).height;

      await tester.tap(find.byKey(const ValueKey('v2_category_retry')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('Sports'), findsOneWidget);
      final loadedHeight = tester.getSize(find.byType(V2HomeCategoryBar)).height;

      expect(loadingHeight, V2HomeCategoryBar.height);
      expect(failedHeight, V2HomeCategoryBar.height);
      expect(loadedHeight, V2HomeCategoryBar.height);
    });

    for (final width in [320.0, 430.0]) {
      testWidgets('long and Tamil labels never overflow at ${width.toInt()}px',
          (tester) async {
        final rig = _Rig(catalog: const [
          {'slug': 'tamil-nadu', 'name': 'தமிழ்நாடு அரசியல் மற்றும் செய்திகள்'},
          {
            'slug': 'science',
            'name': 'Science, Environment and Technology Worldwide Coverage',
          },
          {'slug': 'hindi', 'name': 'राष्ट्रीय समाचार'},
          {'slug': 'kerala', 'name': 'കേരള വാർത്തകൾ'},
          {'slug': 'es', 'name': 'Deportes'},
        ]);
        await rig.filters.syncSavedPreferences();
        rig.filters.toggleCategory('science');
        await tester.pumpWidget(
          _bar(filters: rig.filters, width: width, textScale: 1.6),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(V2HomeCategoryBar)).height,
            V2HomeCategoryBar.height);

        await tester.drag(find.byType(ListView), const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Deportes'), findsOneWidget);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} theme: selected chip uses primary',
          (tester) async {
        final theme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
            brightness: brightness,
          ),
        );
        final rig = _Rig();
        await rig.filters.syncSavedPreferences();
        rig.filters.toggleCategory('sports');
        await tester.pumpWidget(_bar(filters: rig.filters, theme: theme));
        await tester.pumpAndSettle();

        BoxDecoration deco(String label) {
          final box = tester.widget<AnimatedContainer>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return box.decoration! as BoxDecoration;
        }

        Color textColor(String label) =>
            tester.widget<Text>(find.text(label)).style!.color!;

        expect(deco('Sports').color, theme.colorScheme.primary);
        expect(textColor('Sports'), theme.colorScheme.onPrimary);
        expect(deco('Business').color, isNot(theme.colorScheme.primary));
        expect(textColor('Business'), theme.colorScheme.onSurface);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('category row drives the existing Home filter', () {
    test('selecting a category requests the filtered V2 Home feed', () async {
      final rig = _Rig();
      await rig.boot();
      expect(rig.query(rig.last).containsKey('category'), isFalse);

      await rig.tap('sports');
      expect(rig.query(rig.last)['category'], 'sports');
      expect(rig.query(rig.last)['page'], '1');
      expect(rig.ids, [_id('sports', 1)]);
    });

    test('All restores backend saved-preference behavior and keeps prefs',
        () async {
      final rig = _Rig();
      await rig.boot();
      final savedBefore = List.of(rig.filters.savedCategoryTokens);
      await rig.tap('sports');

      await rig.tapAll();
      expect(rig.query(rig.last).containsKey('category'), isFalse);
      expect(rig.ids, [_id('all', 1)]);
      expect(rig.filters.savedCategoryTokens, savedBefore);

      final callsBefore = rig.home.calls.length;
      await rig.tapAll();
      expect(rig.home.calls.length, callsBefore, reason: 'All again is a no-op');
    });

    test('category and location combine; clearing either keeps the other',
        () async {
      final rig = _Rig();
      await rig.boot();
      rig.filters.apply(rig.filters.committed
          .selectCountry('india')
          .selectState('tamil-nadu')
          .selectDistrict('chennai'));
      await rig.reader.refresh();

      await rig.tap('politics');
      final both = rig.query(rig.last);
      expect(both['category'], 'politics');
      expect(both['country'], 'india');
      expect(both['state'], 'tamil-nadu');
      expect(both['city'], 'chennai');

      await rig.tapAll();
      final locationOnly = rig.query(rig.last);
      expect(locationOnly.containsKey('category'), isFalse);
      expect(locationOnly['country'], 'india');
      expect(locationOnly['city'], 'chennai');

      await rig.tap('politics');
      rig.filters.apply(rig.filters.committed.selectCountry(null));
      await rig.reader.refresh();
      final categoryOnly = rig.query(rig.last);
      expect(categoryOnly['category'], 'politics');
      expect(categoryOnly.containsKey('country'), isFalse);
    });

    test('category change resets pagination and loadMore stays scoped',
        () async {
      final rig = _Rig();
      await rig.boot();
      rig.reader.unawaitedLoadMore();
      await _settle();
      expect(rig.reader.state.page, 2);
      expect(rig.ids, [_id('all', 1), _id('all', 2)]);

      await rig.tap('business');
      expect(rig.reader.state.page, 1);
      expect(rig.ids, [_id('business', 1)]);

      rig.reader.unawaitedLoadMore();
      await _settle();
      expect(rig.last.page, 2);
      expect(rig.query(rig.last)['category'], 'business');
      expect(rig.ids, [_id('business', 1), _id('business', 2)]);
    });

    test('pull-to-refresh keeps the active category', () async {
      final rig = _Rig();
      await rig.boot();
      await rig.tap('sports');
      await rig.reader.refresh();
      expect(rig.query(rig.last)['category'], 'sports');
      expect(rig.query(rig.last)['page'], '1');
    });

    test('rapid taps: stale response is discarded and requests coalesce',
        () async {
      final rig = _Rig();
      await rig.boot();
      final bootCalls = rig.home.calls.length;
      rig.home.gates['politics'] = Completer<void>();

      final first = rig.tap('politics');
      await _settle();
      final second = rig.tap('politics');
      await _settle();
      final third = rig.tap('sports');
      await _settle();

      rig.home.gates['politics']!.complete();
      await Future.wait([first, second, third]);

      expect(rig.filters.committed.selectedCategorySlugs, ['sports']);
      expect(rig.ids, [_id('sports', 1)]);
      expect(rig.home.calls.length - bootCalls, 2,
          reason: 'one in-flight + one coalesced re-run');
      expect(rig.query(rig.last)['category'], 'sports');
    });

    test('empty result for a new category shows empty, not old stories',
        () async {
      final rig = _Rig();
      await rig.boot();
      rig.home.emptyCategories.add('sports');
      await rig.tap('sports');
      expect(rig.reader.state.status, V2ReaderStatus.empty);
      expect(rig.reader.state.articles, isEmpty);
    });

    test('empty reload of the same category still keeps the feed', () async {
      final rig = _Rig();
      await rig.boot();
      await rig.tap('sports');
      rig.home.emptyCategories.add('sports');
      await rig.reader.refresh();
      expect(rig.ids, [_id('sports', 1)]);
    });

    test('transient failure on category change keeps the visible feed',
        () async {
      final rig = _Rig();
      await rig.boot();
      rig.home.failCategories.add('sports');
      await rig.tap('sports');
      expect(rig.reader.state.status, V2ReaderStatus.ready);
      expect(rig.ids, [_id('all', 1)]);

      final calls = rig.home.calls.length;
      rig.reader.unawaitedLoadMore();
      await _settle();
      expect(rig.home.calls.length, calls,
          reason: 'no page 2 of Sports appended to the previous feed');
      expect(rig.ids, [_id('all', 1)]);
    });

    test('each page-1 replacement bumps feedSessionRevision once '
        '(Home resets to first page)', () async {
      final rig = _Rig();
      await rig.boot();
      final start = rig.reader.feedSessionRevision;
      await rig.reader.refresh();
      expect(rig.reader.feedSessionRevision, start + 1);
      await rig.tap('sports');
      expect(rig.reader.feedSessionRevision, start + 2);
    });

    test('feedKey ignores category order and language', () {
      const a = HomeFilterState(
        selectedCategorySlugs: ['sports', 'business'],
        country: 'india',
      );
      const b = HomeFilterState(
        selectedCategorySlugs: ['business', 'sports'],
        country: 'india',
      );
      expect(a.feedKey, b.feedKey);
      expect(a.feedKey, isNot(const HomeFilterState().feedKey));
    });
  });

  group('filter sheet is location-only', () {
    Future<HomeFilterState?> openSheet(
      WidgetTester tester,
      _FakeMetadata metadata,
      HomeFilterState initial,
      Future<void> Function() action,
    ) async {
      HomeFilterState? result = const HomeFilterState(country: 'sentinel');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showV2HomeFilterSheet(
                    context,
                    initial: initial,
                    metadataApi: metadata,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await action();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('no category section or category request', (tester) async {
      final metadata = _FakeMetadata(_catalog);
      await openSheet(tester, metadata, const HomeFilterState(), () async {
        expect(find.text('Categories'), findsNothing);
        expect(find.byType(FilterChip), findsNothing);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Country'), findsOneWidget);
        expect(find.text('State'), findsOneWidget);
        expect(find.text('City / District'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      expect(metadata.categoryCalls, 0);
    });

    testWidgets('Apply keeps Home categories and sends location',
        (tester) async {
      final metadata = _FakeMetadata(_catalog);
      final result = await openSheet(
        tester,
        metadata,
        const HomeFilterState(
          selectedCategorySlugs: ['sports'],
          country: 'india',
        ),
        () => tester.tap(find.text('Apply Filters')),
      );
      expect(result!.selectedCategorySlugs, ['sports']);
      expect(result.country, 'india');
    });

    testWidgets('Clear All clears location and keeps Home categories',
        (tester) async {
      final metadata = _FakeMetadata(_catalog);
      final result = await openSheet(
        tester,
        metadata,
        const HomeFilterState(
          selectedCategorySlugs: ['sports'],
          country: 'india',
          state: 'tamil-nadu',
        ),
        () => tester.tap(find.text('Clear All')),
      );
      expect(result!.selectedCategorySlugs, ['sports']);
      expect(result.hasLocation, isFalse);
    });
  });

  group('V2-only wiring', () {
    test('Home puts the row under the header and uses the shared filter', () {
      final home = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      final header = home.indexOf('V2HomeHeader(');
      final bar = home.indexOf('V2HomeCategoryBar(');
      final body = home.indexOf('Expanded(child: _buildBody');
      expect(header, greaterThan(0));
      expect(bar, greaterThan(header));
      expect(body, greaterThan(bar));
      expect(home.contains('categories: _filters.catalog'), isTrue);
      expect(home.contains('_filters.toggleCategory(slug)'), isTrue);
      expect(home.contains('_filters.clearCategories()'), isTrue);
      expect(
          home.contains('filtersActive: _filters.committed.hasSheetFilters'),
          isTrue);
    });

    test('row and sheet never touch V1 category code or routes', () {
      for (final path in [
        'lib/features/home_v2/presentation/widgets/v2_home_category_bar.dart',
        'lib/features/home_v2/presentation/widgets/v2_home_filter_sheet.dart',
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('CategoryProvider'), isFalse, reason: path);
        expect(src.contains('NewsProvider'), isFalse, reason: path);
        expect(src.contains("'/api/news"), isFalse, reason: path);
        expect(src.contains('categories_tab'), isFalse, reason: path);
      }
    });
  });
}
