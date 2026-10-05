import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_display_page.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_pager_session.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_page_turn.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:turnable_page/turnable_page.dart';

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
}

class _Harness {
  _Harness({this.language = 'en'});

  String language;
  HomeFilterState filter = const HomeFilterState();
  final calls = <_Call>[];
  late final V2ReaderController controller = V2ReaderController(
    configService: _readyConfig(),
    newsLanguageCode: () => language,
    appliedRegion: () => const SavedRegion(),
    homeFilter: () => filter,
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

  void answer(
    _Call call,
    List<NewsArticle> articles, {
    bool hasMore = false,
  }) {
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

/// Loads a first feed of [count] articles tagged [tag] and opens [index].
Future<void> _loadAt(_Harness h, String tag, int count, int index) async {
  final future = h.controller.refresh();
  await _settle();
  h.answer(h.calls.last, _articles(tag, count));
  await future;
  expect(h.controller.setIndex(index), isTrue);
}

/// Runs a refresh whose page 1 answers [articles]; returns once applied.
Future<void> _refreshWith(_Harness h, List<NewsArticle> articles) async {
  final future = h.controller.refresh();
  await _settle();
  h.answer(h.calls.last, articles);
  await future;
}

void main() {
  group('manual refresh of the same feed', () {
    for (final (language, index) in [('en', 5), ('ta', 10), ('kn', 6)]) {
      test('$language refresh at article index $index keeps the article; '
          'fresh articles follow it', () async {
        final h = _Harness(language: language);
        await _loadAt(h, '$language-old', 12, index);
        final session = h.session;
        final merges = h.controller.feedMergeRevision;

        final future = h.controller.refresh();
        await _settle();
        // Old feed stays visible (no blank flash) and nothing moves yet.
        expect(h.ids.first, '$language-old-0');
        expect(h.state.index, index);
        expect(h.session, session);
        expect(h.calls.last.page, 1);
        expect(h.calls.last.language, language);

        h.answer(h.calls.last, _articles('$language-new', 12));
        await future;
        expect(h.state.index, index);
        expect(h.state.current?.newsId, '$language-old-$index');
        expect(h.ids[index + 1], '$language-new-0');
        expect(h.ids.length, index + 1 + 12);
        expect(h.ids.toSet().length, h.ids.length);
        expect(h.state.page, 1);
        expect(h.session, session);
        expect(h.controller.feedMergeRevision, merges + 1);
      });
    }

    for (final (language, index) in [('en', 0), ('ta', 2), ('kn', 1)]) {
      test('$language refresh near the top (index $index) opens the '
          'refreshed feed at its first article', () async {
        final h = _Harness(language: language);
        await _loadAt(h, '$language-old', 12, index);
        final session = h.session;

        await _refreshWith(h, _articles('$language-new', 12));
        expect(h.ids.first, '$language-new-0');
        expect(h.state.index, 0);
        expect(h.state.current?.newsId, '$language-new-0');
        expect(h.state.page, 1);
        expect(h.session, session + 1);
      });
    }

    test('repeated refresh near the top: one session step per replacement',
        () async {
      final h = _Harness();
      await _loadAt(h, 'r0', 8, 1);
      final session = h.session;
      for (var n = 1; n <= 3; n++) {
        await _refreshWith(h, _articles('r$n', 8));
        expect(h.session, session + n);
        expect(h.state.index, 0);
        expect(h.ids.first, 'r$n-0');
        h.controller.setIndex(2);
      }
    });

    test('failed refresh keeps the feed and position; recovery keeps it too',
        () async {
      final h = _Harness();
      await _loadAt(h, 'old', 8, 5);
      final session = h.session;

      final failing = h.controller.refresh();
      await _settle();
      h.calls.last.completer.completeError(Exception('offline'));
      await failing;
      expect(h.ids.first, 'old-0');
      expect(h.state.index, 5);
      expect(h.state.status, V2ReaderStatus.ready);
      expect(h.session, session);

      await _refreshWith(h, _articles('new', 8));
      expect(h.state.index, 5);
      expect(h.state.current?.newsId, 'old-5');
      expect(h.ids[6], 'new-0');
      expect(h.session, session);
    });

    test('ignored transient empty page keeps feed, position and session',
        () async {
      final h = _Harness();
      await _loadAt(h, 'old', 8, 5);
      final session = h.session;

      await _refreshWith(h, const []);
      expect(h.ids.first, 'old-0');
      expect(h.state.index, 5);
      expect(h.session, session);
    });

    test('old response arriving after a newer refresh is ignored', () async {
      final h = _Harness();
      await _loadAt(h, 'old', 8, 1);
      final session = h.session;

      final first = h.controller.refresh();
      await _settle();
      final stale = h.calls.last;
      await h.controller.refresh(); // queued: supersedes the first request
      h.answer(stale, _articles('stale', 8));
      await _settle();
      expect(h.ids.first, 'old-0', reason: 'stale page 1 must not be painted');
      expect(h.session, session);

      final fresh = h.calls.last;
      expect(identical(fresh, stale), isFalse);
      h.answer(fresh, _articles('fresh', 8));
      await first;
      expect(h.ids.first, 'fresh-0');
      expect(h.state.index, 0);
      expect(h.session, session + 1);
    });

    test('session changes exactly once per successful replacement', () async {
      final h = _Harness();
      final seen = <int>[h.session];
      h.controller.addListener(() {
        if (seen.last != h.session) seen.add(h.session);
      });
      await _loadAt(h, 'a', 6, 0); // 1
      await _refreshWith(h, _articles('b', 6)); // 2

      final failing = h.controller.refresh();
      await _settle();
      h.calls.last.completer.completeError(Exception('offline'));
      await failing; // no change

      await _refreshWith(h, const []); // transient empty: no change

      h.filter = const HomeFilterState(selectedCategorySlugs: ['sports']);
      await _refreshWith(h, _articles('sports', 6)); // 3

      h.language = 'ta';
      await _refreshWith(h, _articles('ta', 6)); // 4

      h.language = 'kn';
      await _refreshWith(h, const []); // 5: kn feed is empty

      await _refreshWith(h, _articles('kn', 6)); // 6
      expect(seen, [0, 1, 2, 3, 4, 5, 6]);
    });
  });

  group('news language change starts a new feed session', () {
    for (final (from, to) in [
      ('ta', 'kn'),
      ('kn', 'ml'),
      ('ml', 'en'),
      ('en', 'ta'),
    ]) {
      test('$from → $to', () async {
        final h = _Harness(language: from);
        await _loadAt(h, from, 12, 10);
        final session = h.session;

        h.language = to;
        final future = h.controller.refresh();
        await _settle();
        // Previous-language session is dropped right away.
        expect(h.ids, isEmpty);
        expect(h.state.status, V2ReaderStatus.loading);
        expect(h.state.index, 0);
        expect(h.state.page, 1);
        expect(h.calls.last.language, to);
        expect(h.calls.last.page, 1);
        expect(h.session, session);

        h.answer(h.calls.last, _articles(to, 12));
        await future;
        expect(h.ids.every((id) => id.startsWith('$to-')), isTrue);
        expect(h.state.current?.newsId, '$to-0');
        expect(h.state.index, 0);
        expect(h.state.page, 1);
        expect(h.session, session + 1);
      });
    }

    test('rapid ta → kn → ml → en: only en is painted, one session step',
        () async {
      final h = _Harness(language: 'ta');
      await _loadAt(h, 'ta', 12, 10);
      final session = h.session;

      h.language = 'kn';
      final future = h.controller.refresh();
      await _settle();
      final kn = h.calls.last;
      h.language = 'ml';
      await h.controller.refresh();
      h.language = 'en';
      await h.controller.refresh();

      h.answer(kn, _articles('kn', 12)); // superseded
      await _settle();
      expect(h.ids, isEmpty);
      expect(h.session, session);

      final en = h.calls.last;
      expect(en.language, 'en');
      h.answer(en, _articles('en', 12));
      await future;
      expect(h.ids.every((id) => id.startsWith('en-')), isTrue);
      expect(h.state.index, 0);
      expect(h.session, session + 1);
      expect(h.controller.refreshInFlight, isFalse);
    });

    test('change while ta page 2 is in flight: ta page 2 never lands',
        () async {
      final h = _Harness(language: 'ta');
      final first = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last, _articles('ta', 6), hasMore: true);
      await first;
      h.controller.unawaitedLoadMore();
      await _settle();
      final taPage2 = h.calls.last;
      expect(taPage2.page, 2);

      h.language = 'kn';
      final future = h.controller.refresh();
      await _settle();
      h.answer(taPage2, _articles('ta', 6, from: 6)); // lands while loading
      await _settle();
      expect(h.ids, isEmpty);

      h.answer(h.calls.last, _articles('kn', 6));
      await future;
      expect(h.ids.every((id) => id.startsWith('kn-')), isTrue);
      expect(h.state.page, 1);
    });

    test('stale ta page 2 after kn page 1 is not appended', () async {
      final h = _Harness(language: 'ta');
      final first = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last, _articles('ta', 6), hasMore: true);
      await first;
      h.controller.unawaitedLoadMore();
      await _settle();
      final taPage2 = h.calls.last;

      h.language = 'kn';
      await _refreshWith(h, _articles('kn', 6));
      final session = h.session;
      h.answer(taPage2, _articles('ta', 6, from: 6));
      await _settle();
      expect(h.ids, [for (var i = 0; i < 6; i++) 'kn-$i']);
      expect(h.state.page, 1);
      expect(h.session, session);
    });

    test('pagination resets to page 1 and continues in the new language',
        () async {
      final h = _Harness(language: 'ta');
      final first = h.controller.refresh();
      await _settle();
      h.answer(h.calls.last, _articles('ta', 6), hasMore: true);
      await first;
      h.controller.unawaitedLoadMore();
      await _settle();
      h.answer(h.calls.last, _articles('ta', 6, from: 6), hasMore: true);
      await _settle();
      expect(h.state.page, 2);

      h.language = 'kn';
      final future = h.controller.refresh();
      await _settle();
      expect(h.calls.last.page, 1);
      h.answer(h.calls.last, _articles('kn', 6), hasMore: true);
      await future;
      expect(h.state.page, 1);

      h.controller.unawaitedLoadMore();
      await _settle();
      expect(h.calls.last.page, 2);
      expect(h.calls.last.language, 'kn');
    });

    test('visible index resets to 0 on a language change', () async {
      final h = _Harness(language: 'ta');
      await _loadAt(h, 'ta', 12, 9);
      h.language = 'ml';
      await _refreshWith(h, _articles('ml', 12));
      expect(h.state.index, 0);
      expect(h.state.current?.newsId, 'ml-0');
    });
  });

  group('filter change starts exactly one new feed session', () {
    final cases = <(String, HomeFilterState, HomeFilterState)>[
      (
        'country',
        const HomeFilterState(),
        const HomeFilterState(country: 'india'),
      ),
      (
        'state',
        const HomeFilterState(country: 'india'),
        const HomeFilterState(country: 'india', state: 'kerala'),
      ),
      (
        'city',
        const HomeFilterState(country: 'india', state: 'tamil-nadu'),
        const HomeFilterState(
          country: 'india',
          state: 'tamil-nadu',
          district: 'erode',
        ),
      ),
      (
        'category',
        const HomeFilterState(),
        const HomeFilterState(selectedCategorySlugs: ['sports']),
      ),
    ];
    for (final (name, before, after) in cases) {
      test('$name change', () async {
        final h = _Harness(language: 'ta')..filter = before;
        await _loadAt(h, 'before', 10, 7);
        final session = h.session;

        h.filter = after;
        final future = h.controller.refresh();
        await _settle();
        expect(h.calls.last.filter.feedKey, after.feedKey);
        expect(h.calls.last.page, 1);
        expect(h.ids.first, 'before-0');
        expect(h.session, session);

        h.answer(h.calls.last, _articles(name, 10));
        await future;
        expect(h.ids.first, '$name-0');
        expect(h.state.index, 0);
        expect(h.state.page, 1);
        expect(h.session, session + 1);
      });
    }

    test('language + location changed together: one request, one step',
        () async {
      final h = _Harness(language: 'ta');
      await _loadAt(h, 'ta', 10, 6);
      final session = h.session;
      final callsBefore = h.calls.length;

      h.language = 'kn';
      h.filter = const HomeFilterState(country: 'india', state: 'karnataka');
      final future = h.controller.refresh();
      await _settle();
      expect(h.ids, isEmpty);
      expect(h.calls.length, callsBefore + 1);
      expect(h.calls.last.language, 'kn');
      expect(h.calls.last.filter.state, 'karnataka');

      h.answer(h.calls.last, _articles('kn-ka', 10));
      await future;
      expect(h.ids.first, 'kn-ka-0');
      expect(h.state.index, 0);
      expect(h.session, session + 1);
    });
  });

  group('V2ReaderPagerSession', () {
    test('one page-1 replacement is one epoch step at page 0', () async {
      final h = _Harness();
      final pager = V2ReaderPagerSession();
      await _loadAt(h, 'old', 8, 2);
      expect(pager.sync(h.controller, adsEnabled: false),
          V2PagerChange.newFeed);
      final epoch = pager.epoch;
      pager.displayIndex = 2;
      expect(pager.sync(h.controller, adsEnabled: false), V2PagerChange.none);

      await _refreshWith(h, _articles('new', 8));
      expect(pager.sync(h.controller, adsEnabled: false),
          V2PagerChange.newFeed);
      expect(pager.sync(h.controller, adsEnabled: false), V2PagerChange.none);
      expect(pager.epoch, epoch + 1);
      expect(pager.displayIndex, 0);
    });

    test('refresh deeper in the feed is one epoch step on the same article',
        () async {
      final h = _Harness();
      final pager = V2ReaderPagerSession();
      await _loadAt(h, 'old', 8, 5);
      pager.sync(h.controller, adsEnabled: true);
      final epoch = pager.epoch;

      await _refreshWith(h, _articles('new', 8));
      expect(pager.sync(h.controller, adsEnabled: true),
          V2PagerChange.feedMerged);
      expect(pager.sync(h.controller, adsEnabled: true), V2PagerChange.none);
      expect(pager.epoch, epoch + 1);
      expect(h.state.current?.newsId, 'old-5');
      // Article 5 sits after the first ad page (display page 6).
      expect(pager.displayIndex, 6);
    });

    test('Not Interested rebuilds the book on the current article', () async {
      final h = _Harness();
      final pager = V2ReaderPagerSession();
      await _loadAt(h, 'a', 8, 5);
      pager.sync(h.controller, adsEnabled: true);
      final epoch = pager.epoch;

      await h.controller.hideNotInterested(h.state.articles[5]);
      expect(pager.sync(h.controller, adsEnabled: true),
          V2PagerChange.feedEdited);
      expect(pager.epoch, epoch + 1);
      expect(h.state.current?.newsId, 'a-6');
      // Article 5 sits after the first ad page (display page 6).
      expect(pager.displayIndex, 6);
    });

    test('new feed supersedes an article edit seen in the same tick',
        () async {
      final h = _Harness();
      final pager = V2ReaderPagerSession();
      await _loadAt(h, 'a', 8, 2);
      pager.sync(h.controller, adsEnabled: false);
      final epoch = pager.epoch;

      await h.controller.hideNotInterested(h.state.articles[2]);
      await _refreshWith(h, _articles('b', 8));
      expect(pager.sync(h.controller, adsEnabled: false),
          V2PagerChange.newFeed);
      expect(pager.sync(h.controller, adsEnabled: false), V2PagerChange.none);
      expect(pager.epoch, epoch + 1);
      expect(pager.displayIndex, 0);
    });
  });

  group('Home pager session (real TurnablePage)', () {
    testWidgets('refresh near the top opens a new book on new article 1',
        (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('old', 8));
      await _jumpTo(tester, flip, 2);
      final stage = _stage(tester);
      expect(stage.pager.displayIndex, 2);
      expect(h.state.index, 2);

      final keyBefore = _turn(tester).key;
      final feedsBefore = stage.newFeedCount;
      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      // Old feed stays up while loading, same book.
      expect(_turn(tester).key, keyBefore);
      expect(stage.pager.displayIndex, 2);

      h.answer(h.calls.last, _articles('new', 8));
      final keys = <Key?>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        keys.add(_turn(tester).key);
      }
      expect(keys, {ValueKey('v2_turn_${stage.pager.epoch}')});
      expect(keys.single, isNot(keyBefore));
      expect(stage.newFeedCount, feedsBefore + 1);
      expect(stage.pager.displayIndex, 0);
      expect(h.state.index, 0);
      expect(_turn(tester).index, 0);
      expect(flip.currentPageIndex, 0);
      expect(_pageText(tester, 0), 'new-0');
    });

    testWidgets('refresh at page 5 keeps article 6 on screen in a new book; '
        'the next swipe shows the freshest article', (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('old', 8));
      await _jumpTo(tester, flip, 5);
      final stage = _stage(tester);
      final keyBefore = _turn(tester).key;

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      expect(_turn(tester).key, keyBefore);

      h.answer(h.calls.last, _articles('new', 8));
      await _pumpFrames(tester);
      expect(_turn(tester).key, isNot(keyBefore));
      expect(stage.feedMergedCount, 1);
      expect(stage.pager.displayIndex, 5);
      expect(h.state.index, 5);
      expect(flip.currentPageIndex, 5);
      expect(flip.pageCount, 6 + 8);
      expect(_pageText(tester, 5), 'old-5');

      await _swipe(tester, right: false);
      expect(flip.currentPageIndex, 6);
      expect(h.state.current?.newsId, 'new-0');
    });

    testWidgets('ad pages: refresh from display page 6 stays on article 6',
        (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip, adsEnabled: true));
      await _loadInto(tester, h, _articles('old', 8));
      await _jumpTo(tester, flip, 6); // article 5 (ad after the 4th)
      expect(h.state.index, 5);

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('new', 8));
      await _pumpFrames(tester);
      expect(_stage(tester).pager.displayIndex, 6);
      expect(h.state.index, 5);
      expect(flip.currentPageIndex, 6);
      expect(_pageText(tester, 6), 'old-5');
    });

    testWidgets('shorter new feed cannot expose the old page count',
        (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('old', 8));
      await _jumpTo(tester, flip, 1);
      expect(flip.pageCount, 8);

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('new', 3));
      await _pumpFrames(tester);
      expect(flip.pageCount, 3);
      expect(_turn(tester).itemCount, 3);
      expect(flip.currentPageIndex, 0);
      expect(flip.jumpToPage(5), isFalse);
      await _jumpTo(tester, flip, 2);
      expect(flip.hasNextPage, isFalse);
      expect(h.state.current?.newsId, 'new-2');
    });

    testWidgets('filter change mid-read: one book change, first article',
        (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('all', 8));
      await _jumpTo(tester, flip, 4);
      final stage = _stage(tester);
      final epoch = stage.pager.epoch;

      h.filter = const HomeFilterState(country: 'india', district: 'erode');
      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      expect(stage.pager.epoch, epoch);
      h.answer(h.calls.last, _articles('erode', 6));
      await _pumpFrames(tester);
      expect(stage.pager.epoch, epoch + 1);
      expect(stage.pager.displayIndex, 0);
      expect(_pageText(tester, 0), 'erode-0');
    });

    testWidgets('failed refresh keeps the same book and page', (tester) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('old', 8));
      await _jumpTo(tester, flip, 5);
      final epoch = _stage(tester).pager.epoch;

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.calls.last.completer.completeError(Exception('offline'));
      await _pumpFrames(tester);
      expect(_stage(tester).pager.epoch, epoch);
      expect(flip.currentPageIndex, 5);
      expect(h.state.index, 5);
      expect(_pageText(tester, 5), 'old-5');
    });

    testWidgets(
        'language change: fresh book at the first article; swipes stay in '
        'the new session', (tester) async {
      final h = _Harness(language: 'ta');
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip));
      await _loadInto(tester, h, _articles('ta', 8));
      await _jumpTo(tester, flip, 6);
      final stage = _stage(tester);
      final epoch = stage.pager.epoch;

      h.language = 'kn';
      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      // Old-language book is gone while kn loads.
      expect(find.byType(V2PageTurn), findsNothing);

      h.answer(h.calls.last, _articles('kn', 4));
      await _pumpFrames(tester);
      expect(stage.pager.epoch, epoch + 1);
      expect(stage.newFeedCount, 2);
      expect(stage.pager.displayIndex, 0);
      expect(h.state.index, 0);
      expect(flip.currentPageIndex, 0);
      expect(flip.pageCount, 4);
      expect(_pageText(tester, 0), 'kn-0');
      expect(find.textContaining('ta-'), findsNothing);

      // Right swipe (previous) on the first page goes nowhere.
      expect(flip.hasPreviousPage, isFalse);
      expect(await flip.previousPage(), isFalse);
      await _swipe(tester, right: true);
      expect(flip.currentPageIndex, 0);
      expect(h.state.current?.newsId, 'kn-0');

      // Left swipe (next) reaches kn article 2, never a ta page.
      await _swipe(tester, right: false);
      expect(flip.currentPageIndex, 1);
      expect(stage.pager.displayIndex, 1);
      expect(h.state.current?.newsId, 'kn-1');

      await _jumpTo(tester, flip, 3);
      expect(flip.hasNextPage, isFalse, reason: 'no page past the kn feed');
      expect(find.textContaining('ta-'), findsNothing);
    });

    test('V2ReaderHome resets the pager only through V2ReaderPagerSession',
        () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(src.contains('_pager.sync('), isTrue);
      expect(src.contains(r"ValueKey('v2_turn_${_pager.epoch}')"), isTrue);
      expect(
        RegExp(r'turning:\s*_bookBuilt && V2PageTurn\.isTurning\(')
            .hasMatch(src),
        isTrue,
      );
      expect(src.contains('V2PagerChange.pagesDeferred'), isTrue);
      expect(src.contains('_feedEpoch'), isFalse);
      expect(src.contains('_lastStatus'), isFalse);
      expect(src.contains('filterRevision'), isFalse);
    });
  });

  group('load more grows the book (real TurnablePage)', () {
    /// First feed: 20 articles p1-0 … p1-19 with more to load.
    Future<(_Harness, PageFlipController)> boot(
      WidgetTester tester, {
      bool adsEnabled = false,
    }) async {
      final h = _Harness();
      final flip = PageFlipController();
      await tester.pumpWidget(_app(h.controller, flip, adsEnabled: adsEnabled));
      await _loadInto(tester, h, _articles('p1', 20), hasMore: true);
      return (h, flip);
    }

    /// Answers the pending page-[page] request with 20 new articles.
    Future<void> answerPage(
      WidgetTester tester,
      _Harness h,
      int page, {
      bool hasMore = true,
    }) async {
      final call = h.calls.last;
      expect(call.page, page);
      h.answer(
        call,
        _articles('p$page', 20, from: (page - 1) * 20),
        hasMore: hasMore,
      );
      await _pumpFrames(tester);
    }

    testWidgets(
        'page 2 grows the book on the same article; article 21 is next; '
        'page 3 grows it again', (tester) async {
      final (h, flip) = await boot(tester);
      final stage = _stage(tester);
      expect(flip.pageCount, 20);
      await _jumpTo(tester, flip, 16); // article 17 → load-more starts
      expect(h.calls.last.page, 2);
      final session = h.session;
      final epoch = stage.pager.epoch;
      final book = flip.pageFlipInstance;

      await answerPage(tester, h, 2);
      expect(h.state.articles.length, 40);
      expect(flip.pageCount, 40);
      expect(_turn(tester).itemCount, 40);
      expect(stage.pager.epoch, epoch, reason: 'the book grows in place');
      expect(flip.pageFlipInstance, same(book));
      expect(stage.pagesAddedCount, 1);
      expect(h.session, session, reason: 'load-more is not a new session');
      expect(stage.newFeedCount, 1);
      // Same article still on screen.
      expect(flip.currentPageIndex, 16);
      expect(stage.pager.displayIndex, 16);
      expect(h.state.current?.newsId, 'p1-16');
      expect(_pageText(tester, 16), 'p1-16');

      await _jumpTo(tester, flip, 19); // article 20
      await _swipe(tester, right: false);
      expect(flip.currentPageIndex, 20);
      expect(h.state.current?.newsId, 'p2-20', reason: 'article 21');

      await _jumpTo(tester, flip, 36); // page-2 article; loads page 3
      expect(h.state.current?.newsId, 'p2-36');
      await answerPage(tester, h, 3, hasMore: false);
      expect(flip.pageCount, 60);
      expect(stage.pager.epoch, epoch);
      expect(flip.pageFlipInstance, same(book));
      expect(flip.currentPageIndex, 36);
      expect(h.state.current?.newsId, 'p2-36');
      expect(h.session, session);

      await _jumpTo(tester, flip, 59);
      expect(h.state.current?.newsId, 'p3-59');
      expect(flip.hasNextPage, isFalse);
      expect(h.ids.toSet().length, 60, reason: 'no duplicates');
    });

    for (final article in [18, 19, 20]) {
      testWidgets('load-more while on article $article: position kept, '
          'next reaches article ${article + 1}', (tester) async {
        final (h, flip) = await boot(tester);
        await _jumpTo(tester, flip, article - 1);
        expect(h.calls.last.page, 2);
        await answerPage(tester, h, 2);
        expect(flip.pageCount, 40);
        expect(flip.currentPageIndex, article - 1);
        expect(h.state.index, article - 1);

        await _swipe(tester, right: false);
        expect(flip.currentPageIndex, article);
        expect(h.state.index, article);
        await _swipe(tester, right: true);
        expect(flip.currentPageIndex, article - 1);
        expect(h.state.index, article - 1);
      });
    }

    testWidgets('load-more while on an ad page keeps the ad; next is '
        'article 21', (tester) async {
      final (h, flip) = await boot(tester, adsEnabled: true);
      // 20 articles + 5 ads; the last page is the ad after article 20.
      expect(flip.pageCount, 25);
      await _jumpTo(tester, flip, 24);
      expect(_pageText(tester, 24), 'ad-4');
      final index = h.state.index;
      h.controller.unawaitedLoadMore();
      await _pumpFrames(tester);
      await answerPage(tester, h, 2);

      expect(flip.pageCount, 50);
      expect(flip.currentPageIndex, 24);
      expect(_stage(tester).pager.displayIndex, 24);
      expect(_pageText(tester, 24), 'ad-4');
      expect(h.state.index, index);

      await _swipe(tester, right: false);
      expect(flip.currentPageIndex, 25);
      expect(h.state.current?.newsId, 'p2-20');
    });

    testWidgets('arrows: blocked at the old end, continue after growth, '
        'stop at the new end', (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 19);
      expect(flip.hasNextPage, isFalse);
      expect(await flip.nextPage(), isFalse);

      await answerPage(tester, h, 2, hasMore: false);
      expect(flip.hasNextPage, isTrue);
      final done = flip.nextPage();
      await _pumpFrames(tester, frames: 80);
      expect(await done, isTrue);
      expect(flip.currentPageIndex, 20);
      expect(h.state.current?.newsId, 'p2-20');

      await _jumpTo(tester, flip, 39);
      expect(flip.hasNextPage, isFalse);
      expect(await flip.nextPage(), isFalse);
      expect(flip.hasPreviousPage, isTrue);
    });

    testWidgets('pages arriving mid-turn wait for the turn to finish',
        (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 16);
      final stage = _stage(tester);
      final epoch = stage.pager.epoch;

      final turn = flip.nextPage();
      await tester.pump(const Duration(milliseconds: 100));
      expect(V2PageTurn.isTurning(flip), isTrue);
      await answerPage(tester, h, 2);
      expect(stage.pagesDeferredCount, greaterThan(0));
      expect(stage.pager.epoch, epoch, reason: 'turn is not cut off');

      await _pumpFrames(tester, frames: 80);
      expect(await turn, isTrue);
      expect(stage.pager.epoch, epoch);
      expect(flip.pageCount, 40);
      expect(flip.currentPageIndex, 17);
      expect(stage.pager.displayIndex, 17);
      expect(h.state.current?.newsId, 'p1-17');
    });

    testWidgets('failed load-more keeps the book and position',
        (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 17);
      final epoch = _stage(tester).pager.epoch;
      h.calls.last.completer.completeError(Exception('offline'));
      await _pumpFrames(tester);
      expect(_stage(tester).pager.epoch, epoch);
      expect(flip.pageCount, 20);
      expect(flip.currentPageIndex, 17);
      expect(h.state.index, 17);
    });

    testWidgets('empty or duplicate-only load-more does not recreate the book',
        (tester) async {
      final (h, flip) = await boot(tester);
      h.controller.unawaitedLoadMore();
      await _pumpFrames(tester);
      final epoch = _stage(tester).pager.epoch;
      h.answer(h.calls.last, _articles('p1', 5), hasMore: true); // dupes
      await _pumpFrames(tester);
      expect(_stage(tester).pager.epoch, epoch);
      expect(h.state.articles.length, 20);

      h.controller.unawaitedLoadMore();
      await _pumpFrames(tester);
      h.answer(h.calls.last, const []);
      await _pumpFrames(tester);
      expect(_stage(tester).pager.epoch, epoch);
      expect(h.state.hasMore, isFalse);
      expect(flip.pageCount, 20);
    });

    testWidgets('partly duplicate page grows the book by the new items only',
        (tester) async {
      final (h, flip) = await boot(tester);
      h.controller.unawaitedLoadMore();
      await _pumpFrames(tester);
      h.answer(
        h.calls.last,
        [..._articles('p1', 5, from: 15), ..._articles('p2', 5, from: 20)],
      );
      await _pumpFrames(tester);
      expect(h.state.articles.length, 25);
      expect(flip.pageCount, 25);
      expect(h.ids.toSet().length, 25);
    });

    testWidgets('refresh after load-more keeps the article; with no overlap '
        'pagination restarts after page 1', (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 17);
      await answerPage(tester, h, 2);
      await _jumpTo(tester, flip, 30);

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('fresh', 20), hasMore: true);
      await _pumpFrames(tester);
      expect(flip.pageCount, 31 + 20);
      expect(flip.currentPageIndex, 30);
      expect(_stage(tester).pager.displayIndex, 30);
      expect(h.state.current?.newsId, 'p2-30');
      expect(h.ids[31], 'fresh-0');
      expect(h.state.page, 1);
      expect(h.ids.toSet().length, h.ids.length);

      h.controller.unawaitedLoadMore();
      await _pumpFrames(tester);
      expect(h.calls.last.page, 2);
    });

    testWidgets('refresh at article 1 after load-more starts at article 1',
        (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 17);
      await answerPage(tester, h, 2);
      await _jumpTo(tester, flip, 0);

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('fresh', 20), hasMore: true);
      await _pumpFrames(tester);
      expect(flip.pageCount, 20);
      expect(flip.currentPageIndex, 0);
      expect(_stage(tester).pager.displayIndex, 0);
      expect(h.state.current?.newsId, 'fresh-0');
      expect(h.state.page, 1);
    });

    testWidgets('language change after load-more starts at article 1',
        (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 17);
      await answerPage(tester, h, 2);
      await _jumpTo(tester, flip, 30);

      h.language = 'ta';
      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('ta', 20), hasMore: true);
      await _pumpFrames(tester);
      expect(flip.pageCount, 20);
      expect(flip.currentPageIndex, 0);
      expect(h.state.current?.newsId, 'ta-0');
      expect(h.state.page, 1);
    });

    testWidgets('stale load-more after a refresh is ignored', (tester) async {
      final (h, flip) = await boot(tester);
      await _jumpTo(tester, flip, 17);
      final stalePage2 = h.calls.last;
      expect(stalePage2.page, 2);

      unawaited(h.controller.refresh());
      await _pumpFrames(tester);
      h.answer(h.calls.last, _articles('fresh', 10));
      await _pumpFrames(tester);
      final epoch = _stage(tester).pager.epoch;

      h.answer(stalePage2, _articles('p2', 20, from: 20));
      await _pumpFrames(tester);
      expect(_stage(tester).pager.epoch, epoch);
      // Articles 1–18 (read so far) stay; the refreshed page follows them.
      expect(h.state.articles.length, 18 + 10);
      expect(h.ids.skip(18).every((id) => id.startsWith('fresh-')), isTrue);
      expect(h.ids.any((id) => id.startsWith('p2-')), isFalse);
      expect(flip.pageCount, 28);
      expect(flip.currentPageIndex, 17);
    });
  });
}

/// Mirrors V2ReaderHome's pager wiring: [V2ReaderPagerSession] decides the
/// book key and opening page; [V2PageTurn] renders the display pages.
class _Stage extends StatefulWidget {
  const _Stage({
    required this.controller,
    required this.flip,
    required this.adsEnabled,
  });

  final V2ReaderController controller;
  final PageFlipController flip;
  final bool adsEnabled;

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  final pager = V2ReaderPagerSession();
  int newFeedCount = 0;
  int feedMergedCount = 0;
  int pagesAddedCount = 0;
  int pagesDeferredCount = 0;
  bool _bookBuilt = false;
  Timer? _addedPagesRetry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
  }

  void _tick() {
    final change = pager.sync(
      widget.controller,
      adsEnabled: widget.adsEnabled,
      turning: _bookBuilt && V2PageTurn.isTurning(widget.flip),
    );
    switch (change) {
      case V2PagerChange.newFeed:
        newFeedCount++;
      case V2PagerChange.pagesAdded:
        pagesAddedCount++;
      case V2PagerChange.pagesDeferred:
        pagesDeferredCount++;
        _addedPagesRetry ??= Timer(
          const Duration(milliseconds: 200),
          _retryAddedPages,
        );
      case V2PagerChange.feedMerged:
        feedMergedCount++;
      case V2PagerChange.feedEdited:
      case V2PagerChange.none:
        break;
    }
  }

  void _retryAddedPages() {
    _addedPagesRetry = null;
    if (!mounted) return;
    setState(_tick);
  }

  @override
  void dispose() {
    _addedPagesRetry?.cancel();
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final pages = V2ReaderDisplayPages.build(
          state.articles.length,
          adsEnabled: widget.adsEnabled,
        );
        if (pages.isEmpty) return const SizedBox.shrink();
        _bookBuilt = true;
        final safe = pager.displayIndex.clamp(0, pages.length - 1);
        return V2PageTurn(
          key: ValueKey('v2_turn_${pager.epoch}'),
          controller: widget.flip,
          itemCount: pages.length,
          index: safe,
          canGoNext: safe < pages.length - 1 || state.hasMore,
          canGoPrevious: safe > 0,
          onIndexChanged: (i) {
            setState(() => pager.displayIndex = i);
            final article = V2ReaderDisplayPages.articleIndexAt(pages, i);
            if (article != null) widget.controller.setIndex(article);
          },
          itemBuilder: (context, i) {
            final page = pages[i];
            final label = page is V2ReaderArticleDisplay
                ? state.articles[page.articleIndex].newsId!
                : 'ad-${(page as V2ReaderAdDisplay).slotIndex}';
            return Center(key: ValueKey('page-$i'), child: Text(label));
          },
        );
      },
    );
  }
}

Widget _app(
  V2ReaderController controller,
  PageFlipController flip, {
  bool adsEnabled = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: _Stage(
          controller: controller,
          flip: flip,
          adsEnabled: adsEnabled,
        ),
      ),
    );

_StageState _stage(WidgetTester tester) =>
    tester.state<_StageState>(find.byType(_Stage));

V2PageTurn _turn(WidgetTester tester) =>
    tester.widget<V2PageTurn>(find.byType(V2PageTurn));

String? _pageText(WidgetTester tester, int page) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('page-$page')),
        matching: find.byType(Text),
      ),
    )
    .data;

Future<void> _pumpFrames(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _loadInto(
  WidgetTester tester,
  _Harness h,
  List<NewsArticle> articles, {
  bool hasMore = false,
}) async {
  unawaited(h.controller.refresh());
  await _pumpFrames(tester);
  h.answer(h.calls.last, articles, hasMore: hasMore);
  await _pumpFrames(tester);
}

Future<void> _jumpTo(
  WidgetTester tester,
  PageFlipController flip,
  int page,
) async {
  expect(flip.jumpToPage(page), isTrue);
  await _pumpFrames(tester);
}

/// Horizontal drag across the book: right = previous, left = next.
Future<void> _swipe(WidgetTester tester, {required bool right}) async {
  final box = tester.getRect(find.byType(TurnablePage));
  final y = box.center.dy;
  final start = right
      ? Offset(box.left + box.width * 0.2, y)
      : Offset(box.right - box.width * 0.1, y);
  final delta = Offset((right ? 1 : -1) * box.width * 0.7, 0);
  await tester.timedDragFrom(start, delta, const Duration(milliseconds: 300));
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
