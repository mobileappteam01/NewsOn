import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/home_v2/data/v2_home_api.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_effective_categories.dart';
import 'package:newson/features/home_v2/domain/v2_home_date_window.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_home_filter_sheet.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

// —— helpers ————————————————————————————————————————————————————————————

List<NewsArticle> _articles(String tag, int count, {int from = 0}) => [
      for (var i = from; i < from + count; i++)
        NewsArticle(articleId: '$tag-$i', newsId: '$tag-$i', title: '$tag $i'),
    ];

V2ApiConfigService _readyConfig() {
  const config = V2ApiConfig(
    baseUrl: 'https://v2-api.newson.app',
    enabled: true,
  );
  return V2ApiConfigService(
    fetcher: () async => config,
    cacheReader: () => null,
    cacheWriter: (_) async {},
  )..debugSetConfig(config);
}

class _Call {
  _Call(this.page, this.language, this.filter);
  final int page;
  final String language;
  final HomeFilterState filter;
  final Completer<V2FeedPage> completer = Completer<V2FeedPage>();

  Map<String, String> get query =>
      filter.toQueryParameters(language: language, page: page, limit: 20);
}

/// Mirrors Home: request filter = forRequest(committed), language from provider.
class _Harness {
  _Harness({this.language = 'en'});

  String language;
  HomeFilterState committed = const HomeFilterState();
  final calls = <_Call>[];
  late final V2ReaderController controller = V2ReaderController(
    configService: _readyConfig(),
    newsLanguageCode: () => language,
    appliedRegion: () => const SavedRegion(),
    homeFilter: () => V2EffectiveHomeFilter.forRequest(committed),
    notInterested: (_) async {},
    homeLoader: ({
      required page,
      required limit,
      required language,
      required filter,
    }) {
      final call = _Call(page, language, filter);
      calls.add(call);
      return call.completer.future;
    },
  );

  void answer(_Call call, List<NewsArticle> articles, {bool hasMore = false}) {
    call.completer.complete(
      V2FeedPage(articles: articles, page: call.page, hasMore: hasMore),
    );
  }

  int get session => controller.feedSessionRevision;
  V2ReaderState get state => controller.state;
  List<String> get ids => [for (final a in state.articles) a.newsId!];
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _load(_Harness h, String tag, int count,
    {bool hasMore = false}) async {
  final future = h.controller.refresh();
  await _settle();
  h.answer(h.calls.last, _articles(tag, count), hasMore: hasMore);
  await future;
}

class _Regions extends V2HomeMetadataApi {
  _Regions({
    this.countries = const [],
    this.states = const [],
    this.cities = const [],
  });

  final List<V2RegionOption> countries;
  final List<V2RegionOption> states;
  final List<V2RegionOption> cities;

  @override
  Future<List<V2RegionOption>> fetchCountries() async => countries;

  @override
  Future<List<V2RegionOption>> fetchStates(String country) async => states;

  @override
  Future<List<V2RegionOption>> fetchCities({
    required String country,
    required String state,
  }) async =>
      cities;
}

class _Popped {
  HomeFilterState? value;
  bool closed = false;
}

/// 2026-09-28 15:30 IST.
final _clockInstant = DateTime.utc(2026, 9, 28, 10, 0);

void main() {
  // —— Asia/Kolkata date window ————————————————————————————————————————

  group('V2HomeDateWindow — Asia/Kolkata calendar', () {
    final now = _clockInstant;

    test('selectable = today back to today - 6 (7 days)', () {
      expect(V2HomeDateWindow.today(now: now), DateTime(2026, 9, 28));
      expect(V2HomeDateWindow.firstDay(now: now), DateTime(2026, 9, 22));
      bool ok(int d) =>
          V2HomeDateWindow.isSelectable(DateTime(2026, 9, d), now: now);
      expect(ok(28), isTrue, reason: 'today');
      expect(ok(27), isTrue, reason: 'today - 1');
      expect(ok(22), isTrue, reason: 'today - 6');
      expect(ok(21), isFalse, reason: 'today - 7');
      expect(ok(29), isFalse, reason: 'tomorrow');
      final enabled = [
        for (var d = 15; d <= 30; d++)
          if (ok(d)) d,
      ];
      expect(enabled, [22, 23, 24, 25, 26, 27, 28]);
    });

    test('device clock in UTC-8 still uses the Asia/Kolkata date', () {
      // 23:00 on Sep 28 in UTC-8 = Sep 29 12:30 IST.
      final late = DateTime.parse('2026-09-28T23:00:00-08:00');
      expect(V2HomeDateWindow.today(now: late), DateTime(2026, 9, 29));
      expect(V2HomeDateWindow.firstDay(now: late), DateTime(2026, 9, 23));
      // 08:00 on Sep 27 in UTC-8 = Sep 27 21:30 IST.
      final morning = DateTime.parse('2026-09-27T08:00:00-08:00');
      expect(V2HomeDateWindow.today(now: morning), DateTime(2026, 9, 27));
    });

    test('device clock in UTC+14 still uses the Asia/Kolkata date', () {
      // 00:30 on Sep 29 in UTC+14 = Sep 28 16:00 IST.
      final early = DateTime.parse('2026-09-29T00:30:00+14:00');
      expect(V2HomeDateWindow.today(now: early), DateTime(2026, 9, 28));
      expect(
        V2HomeDateWindow.isSelectable(DateTime(2026, 9, 29), now: early),
        isFalse,
        reason: 'device shows Sep 29 but it is still Sep 28 in IST',
      );
    });

    test('midnight rollover happens at 18:30Z (00:00 IST)', () {
      final before = DateTime.utc(2026, 9, 28, 18, 29, 59);
      final after = DateTime.utc(2026, 9, 28, 18, 30);
      expect(V2HomeDateWindow.today(now: before), DateTime(2026, 9, 28));
      expect(V2HomeDateWindow.today(now: after), DateTime(2026, 9, 29));
      final oldest = DateTime(2026, 9, 22);
      expect(V2HomeDateWindow.isSelectable(oldest, now: before), isTrue);
      expect(V2HomeDateWindow.isSelectable(oldest, now: after), isFalse);
      expect(
        V2HomeDateWindow.isSelectable(DateTime(2026, 9, 29), now: after),
        isTrue,
      );
    });

    test('month and year boundaries', () {
      final jan1 = DateTime.utc(2026, 12, 31, 20, 0); // Jan 1 01:30 IST
      expect(V2HomeDateWindow.today(now: jan1), DateTime(2027, 1, 1));
      expect(V2HomeDateWindow.firstDay(now: jan1), DateTime(2026, 12, 26));
    });

    test('YYYY-MM-DD format and strict parse', () {
      expect(V2HomeDateWindow.format(DateTime(2026, 9, 7)), '2026-09-07');
      expect(V2HomeDateWindow.parse('2026-09-28'), DateTime(2026, 9, 28));
      for (final bad in [null, '', '28-09-2026', '2026-9-28', '2026-02-31']) {
        expect(V2HomeDateWindow.parse(bad), isNull, reason: '$bad');
      }
    });

    test('picker opens on the saved day, or today once it aged out', () {
      expect(
        V2HomeDateWindow.initialPickerDay('2026-09-24', now: now),
        DateTime(2026, 9, 24),
      );
      expect(
        V2HomeDateWindow.initialPickerDay('2026-09-10', now: now),
        DateTime(2026, 9, 28),
      );
      expect(
        V2HomeDateWindow.initialPickerDay(null, now: now),
        DateTime(2026, 9, 28),
      );
    });

    test('picker locale follows the UI language (ml/te/kn included)', () {
      const fallback = Locale('en');
      for (final code in ['en', 'ta', 'hi', 'ml', 'te', 'kn']) {
        expect(V2HomeDateWindow.pickerLocale(code, fallback), Locale(code));
      }
      expect(V2HomeDateWindow.pickerLocale('xx', fallback), fallback);
      expect(V2HomeDateWindow.pickerLocale(null, fallback), fallback);
    });
  });

  // —— Filter state + request ——————————————————————————————————————————

  group('HomeFilterState date', () {
    Map<String, String> q(HomeFilterState f, String lang) =>
        f.toQueryParameters(language: lang, page: 1, limit: 20);

    test('English + Kerala + Sep 28 sends date', () {
      const f = HomeFilterState(
        country: 'india',
        state: 'kerala',
        district: 'kochi',
        date: '2026-09-28',
      );
      expect(q(f, 'en'), {
        'page': '1',
        'limit': '20',
        'language': 'en',
        'country': 'india',
        'state': 'kerala',
        'city': 'kochi',
        'date': '2026-09-28',
      });
    });

    test('Tamil + Chennai + Sep 27 sends date', () {
      const f = HomeFilterState(
        country: 'india',
        state: 'tamil nadu',
        district: 'chennai',
        date: '2026-09-27',
      );
      final query = q(f, 'ta');
      expect(query['language'], 'ta');
      expect(query['city'], 'chennai');
      expect(query['date'], '2026-09-27');
    });

    test('date only sends date; no date omits the parameter', () {
      expect(q(const HomeFilterState(date: '2026-09-28'), 'en')['date'],
          '2026-09-28');
      expect(q(const HomeFilterState(country: 'india'), 'en'),
          isNot(contains('date')));
      expect(q(const HomeFilterState(date: '  '), 'en'),
          isNot(contains('date')));
    });

    test('changing the date changes feedKey', () {
      const a = HomeFilterState(country: 'india', date: '2026-09-27');
      const b = HomeFilterState(country: 'india', date: '2026-09-28');
      const none = HomeFilterState(country: 'india');
      expect(a.feedKey, isNot(b.feedKey));
      expect(a.feedKey, isNot(none.feedKey));
      expect(
        V2ReaderController.feedIdentity('en', a),
        isNot(V2ReaderController.feedIdentity('en', b)),
      );
    });

    test('hasDate / hasSheetFilters / isActive / clearDate', () {
      const f = HomeFilterState(date: '2026-09-28');
      expect(f.hasDate, isTrue);
      expect(f.hasLocation, isFalse);
      expect(f.hasSheetFilters, isTrue);
      expect(f.isActive, isTrue);
      expect(f.copyWith(clearDate: true).hasDate, isFalse);
      expect(f.selectDate(null).hasDate, isFalse);
      expect(const HomeFilterState().hasSheetFilters, isFalse);
    });

    test('location changes keep the date; date changes keep location', () {
      const f = HomeFilterState(
        country: 'india',
        state: 'kerala',
        district: 'kochi',
        date: '2026-09-28',
      );
      final newCountry = f.selectCountry('united states');
      expect(newCountry.state, isNull, reason: 'parent change clears child');
      expect(newCountry.district, isNull);
      expect(newCountry.date, '2026-09-28');
      final newState = f.selectState('tamil nadu');
      expect(newState.district, isNull);
      expect(newState.date, '2026-09-28');
      final newDate = f.selectDate('2026-09-27');
      expect(newDate.country, 'india');
      expect(newDate.state, 'kerala');
      expect(newDate.district, 'kochi');
    });

    test('forRequest retains the date', () {
      expect(
        V2EffectiveHomeFilter.forRequest(
                const HomeFilterState(date: '2026-09-28'))
            .date,
        '2026-09-28',
      );
      final withLocation = V2EffectiveHomeFilter.forRequest(
        const HomeFilterState(country: 'india', date: '2026-09-27'),
      );
      expect(withLocation.date, '2026-09-27');
      expect(withLocation.country, 'india');
      final withCategories = V2EffectiveHomeFilter.forRequest(
        const HomeFilterState(
          selectedCategorySlugs: ['sports'],
          date: '2026-09-26',
        ),
      );
      expect(withCategories.date, '2026-09-26');
      expect(withCategories.selectedCategorySlugs, ['sports']);
    });
  });

  // —— Controller session / pagination ————————————————————————————————

  group('date filter feed session', () {
    test('Apply date: one page-1 request, one session step, article 1',
        () async {
      final h = _Harness();
      await _load(h, 'all', 10);
      h.controller.setIndex(6);
      final session = h.session;
      final before = h.calls.length;

      h.committed = h.committed.selectDate('2026-09-28');
      final future = h.controller.refresh();
      await _settle();
      expect(h.calls.length, before + 1, reason: 'exactly one request');
      expect(h.calls.last.page, 1);
      expect(h.calls.last.query['date'], '2026-09-28');
      h.answer(h.calls.last, _articles('d28', 10));
      await future;

      expect(h.session, session + 1);
      expect(h.state.index, 0);
      expect(h.state.current?.newsId, 'd28-0');
      expect(h.calls.length, before + 1);
    });

    test('load more after a date filter keeps date, language and location',
        () async {
      final h = _Harness(language: 'ml');
      h.committed = const HomeFilterState(
        country: 'india',
        state: 'kerala',
        district: 'kochi',
        date: '2026-09-28',
      );
      await _load(h, 'p1', 20, hasMore: true);
      h.controller.unawaitedLoadMore();
      await _settle();
      final next = h.calls.last;
      expect(next.page, 2);
      expect(next.language, 'ml');
      expect(next.query['date'], '2026-09-28');
      expect(next.query['city'], 'kochi');
      h.answer(next, _articles('p2', 20));
      await _settle();
      expect(h.ids.length, 40);
      expect(h.ids.first, 'p1-0');
    });

    test('changing the date: old-date response is ignored, never appended',
        () async {
      final h = _Harness();
      h.committed = const HomeFilterState(date: '2026-09-27');
      await _load(h, 'd27', 20, hasMore: true);
      final session = h.session;

      // Load-more for Sep 27 in flight while the user picks Sep 28.
      h.controller.unawaitedLoadMore();
      await _settle();
      final oldMore = h.calls.last;
      h.committed = h.committed.selectDate('2026-09-28');
      final future = h.controller.refresh();
      await _settle();
      final fresh = h.calls.last;
      expect(fresh.query['date'], '2026-09-28');
      h.answer(oldMore, _articles('d27more', 20));
      await _settle();
      expect(h.ids.any((id) => id.startsWith('d27more')), isFalse);

      h.answer(fresh, _articles('d28', 5));
      await future;
      expect(h.ids, [for (var i = 0; i < 5; i++) 'd28-$i']);
      expect(h.session, session + 1);
      expect(h.state.index, 0);
    });

    test('language change keeps date and location; old language ignored',
        () async {
      final h = _Harness(language: 'en');
      h.committed = const HomeFilterState(
        country: 'india',
        state: 'tamil nadu',
        district: 'chennai',
        date: '2026-09-27',
      );
      await _load(h, 'en', 10);
      h.controller.setIndex(4);
      final session = h.session;

      final enRefresh = h.controller.refresh();
      await _settle();
      final staleEn = h.calls.last;
      h.language = 'ta';
      await h.controller.refresh(); // queued behind the in-flight request
      h.answer(staleEn, _articles('en-late', 10));
      await _settle();
      final ta = h.calls.last;
      expect(ta.language, 'ta');
      expect(ta.query['date'], '2026-09-27');
      expect(ta.query['city'], 'chennai');
      h.answer(ta, _articles('ta', 10));
      await enRefresh;

      expect(h.ids.first, 'ta-0');
      expect(h.ids.any((id) => id.startsWith('en')), isFalse);
      expect(h.state.index, 0);
      expect(h.session, session + 1);
      expect(h.committed.date, '2026-09-27');
      expect(h.committed.district, 'chennai');
    });

    for (final (lang, state, city) in [
      ('ta', 'tamil nadu', 'chennai'),
      ('ml', 'kerala', 'kochi'),
      ('en', 'kerala', 'kochi'),
    ]) {
      test('$lang + $city + date: request carries exactly that language',
          () async {
        final h = _Harness(language: lang);
        h.committed = HomeFilterState(
          country: 'india',
          state: state,
          district: city,
          date: '2026-09-28',
        );
        await _load(h, lang, 3);
        final query = h.calls.single.query;
        expect(query['language'], lang);
        expect(query['state'], state);
        expect(query['city'], city);
        expect(query['date'], '2026-09-28');
      });
    }
  });

  // —— Previous-feed state (loading / error UX) ————————————————————————

  group('showingPreviousFeed', () {
    test('true while the new filter loads, false once it lands', () async {
      final h = _Harness();
      await _load(h, 'all', 8);
      expect(h.controller.showingPreviousFeed, isFalse);

      h.committed = const HomeFilterState(date: '2026-09-28');
      final future = h.controller.refresh();
      await _settle();
      expect(h.controller.showingPreviousFeed, isTrue);
      expect(h.controller.refreshInFlight, isTrue);
      expect(h.ids.first, 'all-0', reason: 'no blank flash while loading');

      h.answer(h.calls.last, _articles('d28', 4));
      await future;
      expect(h.controller.showingPreviousFeed, isFalse);
      expect(h.ids.first, 'd28-0');
    });

    for (final (label, error) in [
      ('400', V2HomeException('Invalid date', statusCode: 400)),
      ('500', V2HomeException('boom', statusCode: 500, kind: V2HomeFailureKind.server)),
      ('network', V2HomeException('offline', kind: V2HomeFailureKind.network)),
    ]) {
      test('$label failure on a filter change flags the previous feed',
          () async {
        final h = _Harness();
        await _load(h, 'all', 8);
        final session = h.session;

        h.committed = const HomeFilterState(
          country: 'india',
          date: '2026-09-28',
        );
        final failing = h.controller.refresh();
        await _settle();
        h.calls.last.completer.completeError(error);
        await failing;

        expect(h.controller.refreshInFlight, isFalse);
        expect(h.controller.showingPreviousFeed, isTrue,
            reason: 'Home must show the filter error, not old articles');
        expect(h.session, session, reason: 'failure does not reset the pager');

        await _load(h, 'retry', 3);
        expect(h.controller.showingPreviousFeed, isFalse);
        expect(h.ids.first, 'retry-0');
        expect(h.session, session + 1);
      });
    }

    test('same-filter refresh failure keeps the feed as current', () async {
      final h = _Harness();
      h.committed = const HomeFilterState(date: '2026-09-28');
      await _load(h, 'd28', 8);
      final failing = h.controller.refresh();
      await _settle();
      h.calls.last.completer.completeError(Exception('offline'));
      await failing;
      expect(h.controller.showingPreviousFeed, isFalse);
      expect(h.ids.first, 'd28-0');
      expect(h.state.status, V2ReaderStatus.ready);
    });

    test('empty result for a new filter replaces the feed (empty state)',
        () async {
      final h = _Harness();
      await _load(h, 'all', 8);
      h.committed = const HomeFilterState(date: '2026-09-22');
      final future = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last, const []);
      await future;
      expect(h.state.status, V2ReaderStatus.empty);
      expect(h.state.articles, isEmpty);
      expect(h.controller.showingPreviousFeed, isFalse);
    });
  });

  // —— Filter sheet UI ————————————————————————————————————————————————

  group('filter sheet', () {
    /// Opens the sheet; [_Popped.value] is what the sheet returned on close.
    Future<_Popped> pumpSheet(
      WidgetTester tester,
      HomeFilterState initial,
      V2HomeMetadataApi metadata,
    ) async {
      final popped = _Popped();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped.value = await showModalBottomSheet<HomeFilterState>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => V2HomeFilterSheet(
                      initial: initial,
                      metadataApi: metadata,
                      clock: () => _clockInstant,
                    ),
                  );
                  popped.closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return popped;
    }

    DropdownButton<String?> dropdown(WidgetTester tester, String key) =>
        tester.widget<DropdownButton<String?>>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byWidgetPredicate((w) => w is DropdownButton<String?>),
          ),
        );

    List<String> labels(WidgetTester tester, String key) => [
          for (final item in dropdown(tester, key).items!.skip(1))
            (item.child as Text).data!,
        ];

    final regions = _Regions(
      countries: const [
        V2RegionOption(slug: 'united states', name: 'united states'),
        V2RegionOption(slug: 'india', name: 'India'),
        V2RegionOption(slug: 'united arab emirates', name: 'UAE'),
        V2RegionOption(slug: 'bhutan', name: 'bhutan'),
      ],
      states: const [
        V2RegionOption(slug: 'tamil nadu', name: 'tamil nadu'),
        V2RegionOption(slug: 'andhra pradesh', name: 'Andhra Pradesh'),
        V2RegionOption(slug: 'kerala', name: 'kerala'),
      ],
      cities: const [
        V2RegionOption(slug: 'madurai', name: 'madurai'),
        V2RegionOption(slug: 'chennai', name: 'chennai'),
        V2RegionOption(slug: 'சென்னை', name: 'சென்னை'),
        V2RegionOption(slug: 'coimbatore', name: 'Coimbatore'),
      ],
    );

    const selected = HomeFilterState(
      country: 'india',
      state: 'tamil nadu',
      district: 'chennai',
      date: '2026-09-27',
    );

    testWidgets('countries, states and cities are Title Case A–Z',
        (tester) async {
      await pumpSheet(tester, selected, regions);
      expect(labels(tester, 'v2_filter_country'),
          ['Bhutan', 'India', 'UAE', 'United States']);
      expect(labels(tester, 'v2_filter_state'),
          ['Andhra Pradesh', 'Kerala', 'Tamil Nadu']);
      expect(labels(tester, 'v2_filter_city'),
          ['Chennai', 'Coimbatore', 'Madurai', 'சென்னை']);
      // Canonical values are untouched.
      expect(
        dropdown(tester, 'v2_filter_state').items!.map((i) => i.value),
        [null, 'andhra pradesh', 'kerala', 'tamil nadu'],
      );
    });

    test('local scripts are never re-cased; acronyms stay', () {
      expect(formatRegionLabel('சென்னை'), 'சென்னை');
      expect(formatRegionLabel('दिल्ली'), 'दिल्ली');
      expect(formatRegionLabel('കൊച്ചി'), 'കൊച്ചി');
      expect(formatRegionLabel('హైదరాబాద్'), 'హైదరాబాద్');
      expect(formatRegionLabel('ಬೆಂಗಳೂರು'), 'ಬೆಂಗಳೂರು');
      expect(formatRegionLabel('UAE'), 'UAE');
      final sorted = sortRegionOptions(const [
        V2RegionOption(slug: 'b', name: 'beta'),
        V2RegionOption(slug: 'a', name: 'Alpha'),
        V2RegionOption(slug: 'c', name: 'ALPHA'),
      ]);
      expect(sorted.map((o) => o.slug), ['a', 'c', 'b']);
    });

    testWidgets('three-line summary is gone; reopening keeps selections',
        (tester) async {
      await pumpSheet(tester, selected, regions);
      expect(find.textContaining('India\nTamil Nadu'), findsNothing);
      expect(find.textContaining('\n'), findsNothing);
      expect(dropdown(tester, 'v2_filter_country').value, 'india');
      expect(dropdown(tester, 'v2_filter_state').value, 'tamil nadu');
      expect(dropdown(tester, 'v2_filter_city').value, 'chennai');
      expect(find.text('Tamil Nadu'), findsOneWidget);
      expect(find.text('Chennai'), findsOneWidget);
      expect(find.textContaining('Sun, Sep 27'), findsOneWidget);
      expect(find.text('Any date'), findsNothing);
    });

    testWidgets('a saved region missing from the list still displays',
        (tester) async {
      final partial = _Regions(
        countries: const [V2RegionOption(slug: 'india', name: 'India')],
        states: const [V2RegionOption(slug: 'tamil nadu', name: 'tamil nadu')],
      );
      await pumpSheet(
        tester,
        const HomeFilterState(
          country: 'india',
          state: 'kerala',
          district: 'kochi',
        ),
        partial,
      );
      expect(dropdown(tester, 'v2_filter_state').value, 'kerala');
      expect(dropdown(tester, 'v2_filter_city').value, 'kochi');
      expect(find.text('Kerala'), findsOneWidget);
      expect(find.text('Kochi'), findsOneWidget);
    });

    testWidgets('Apply returns the saved date and location unchanged',
        (tester) async {
      final popped = await pumpSheet(tester, selected, regions);
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(popped.closed, isTrue);
      expect(popped.value!.country, 'india');
      expect(popped.value!.state, 'tamil nadu');
      expect(popped.value!.district, 'chennai');
      expect(popped.value!.date, '2026-09-27');
    });

    testWidgets('dismissing the sheet returns null (feed unchanged)',
        (tester) async {
      final popped = await pumpSheet(tester, selected, regions);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(popped.closed, isTrue);
      expect(popped.value, isNull);
    });

    testWidgets('picking a date: only today..today-6 is selectable',
        (tester) async {
      final popped = await pumpSheet(
        tester,
        const HomeFilterState(
          selectedCategorySlugs: ['sports'],
          country: 'india',
        ),
        regions,
      );
      expect(find.text('Any date'), findsOneWidget);

      Future<void> pick(String day) async {
        await tester.tap(find.byKey(const ValueKey('v2_filter_date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(day));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      // Tomorrow and today - 7 are disabled: the picker keeps today.
      await pick('29');
      expect(find.textContaining('Mon, Sep 28'), findsOneWidget);
      await pick('21');
      expect(find.textContaining('Mon, Sep 28'), findsOneWidget);
      // today - 6 is selectable.
      await pick('22');
      expect(find.textContaining('Tue, Sep 22'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(popped.value!.date, '2026-09-22');
      expect(popped.value!.country, 'india');
      expect(popped.value!.selectedCategorySlugs, ['sports']);
    });

    for (final code in ['ta', 'hi', 'ml', 'te', 'kn']) {
      testWidgets('date picker renders in $code while the app locale is en',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDatePicker(
                  context: context,
                  initialDate: V2HomeDateWindow.today(now: _clockInstant),
                  firstDate: V2HomeDateWindow.firstDay(now: _clockInstant),
                  lastDate: V2HomeDateWindow.today(now: _clockInstant),
                  locale: V2HomeDateWindow.pickerLocale(
                    code,
                    const Locale('en'),
                  ),
                ),
                child: const Text('pick'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('pick'));
        await tester.pumpAndSettle();
        final picker = find.byType(CalendarDatePicker);
        expect(picker, findsOneWidget);
        expect(Localizations.localeOf(tester.element(picker)), Locale(code));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('clear-date icon removes only the date', (tester) async {
      final popped = await pumpSheet(tester, selected, regions);
      await tester.tap(find.byKey(const ValueKey('v2_filter_date_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Any date'), findsOneWidget);
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(popped.value!.hasDate, isFalse);
      expect(popped.value!.district, 'chennai');
    });

    testWidgets('Clear All clears location and date, keeps categories',
        (tester) async {
      final popped = await pumpSheet(
        tester,
        const HomeFilterState(
          selectedCategorySlugs: ['sports', 'business'],
          country: 'india',
          state: 'tamil nadu',
          district: 'chennai',
          date: '2026-09-27',
        ),
        regions,
      );
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(popped.value!.hasLocation, isFalse);
      expect(popped.value!.hasDate, isFalse);
      expect(popped.value!.selectedCategorySlugs, ['sports', 'business']);
    });
  });

  // —— Wiring + localization ——————————————————————————————————————————

  group('wiring', () {
    final home =
        File('lib/features/home_v2/presentation/v2_reader_home.dart')
            .readAsStringSync();
    final sheet =
        File('lib/features/home_v2/presentation/widgets/v2_home_filter_sheet.dart')
            .readAsStringSync();

    test('date-only filter lights the filter badge', () {
      expect(home, contains('filtersActive: _filters.committed.hasSheetFilters'));
    });

    test('Home shows loading/error for a previous-filter feed', () {
      expect(home, contains('_controller.showingPreviousFeed'));
      expect(home, contains('_PendingFeedOverlay('));
      expect(home, contains('LocalizationHelper.v2FilterLoadError(context)'));
      expect(home, contains('LocalizationHelper.v2FilterNoResults(context)'));
      expect(home, isNot(contains("'No news found for the selected filters'")));
    });

    test('sheet: no summary join, IST picker bounds, localized picker', () {
      expect(sheet, isNot(contains(".join('\\n')")));
      expect(sheet, contains('firstDate: V2HomeDateWindow.firstDay(now: now)'));
      expect(sheet, contains('lastDate: V2HomeDateWindow.today(now: now)'));
      expect(sheet, contains('locale: V2HomeDateWindow.pickerLocale('));
      expect(sheet, isNot(contains("'Filters'")));
      expect(sheet, isNot(contains("'Apply Filters'")));
    });
  });

  group('localization keys', () {
    const keys = [
      'v2FilterTitle',
      'v2FilterClearAll',
      'v2FilterLocation',
      'v2FilterCountry',
      'v2FilterState',
      'v2FilterCity',
      'v2FilterAny',
      'v2FilterSelectAbove',
      'v2FilterDate',
      'v2FilterAnyDate',
      'v2FilterClearDate',
      'v2FilterApply',
      'v2FilterOptionsError',
      'v2FilterLoading',
      'v2FilterNoResults',
      'v2FilterLoadError',
    ];

    Map<String, dynamic> load(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    test('every bundled and Firebase language has every filter key', () {
      final files = [
        for (final l in ['en', 'es', 'fr', 'hi', 'kn', 'ml', 'ta', 'te'])
          'assets/languages/$l.json',
        for (final l in ['en', 'hi', 'kn', 'ml', 'ta', 'te'])
          'firebase_languages/$l.json',
      ];
      for (final path in files) {
        final json = load(path);
        for (final key in keys) {
          expect((json[key] as String?)?.trim(), isNotEmpty,
              reason: '$path is missing $key');
        }
      }
    });

    test('ta/hi/ml/te/kn are translated, not English copies', () {
      final en = load('assets/languages/en.json');
      for (final l in ['ta', 'hi', 'ml', 'te', 'kn']) {
        final json = load('assets/languages/$l.json');
        for (final key in keys) {
          expect(json[key], isNot(en[key]), reason: '$l.$key');
        }
      }
    });
  });
}
