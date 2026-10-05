import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home_v2/data/v2_home_api.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_category_badge.dart';
import 'package:newson/features/home_v2/domain/v2_effective_categories.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_home_filter_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_page.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

/// Staging-shaped article pool: NewsData stores `top` first on most stories.
const _combos = <List<String>>[
  ['top', 'business'],
  ['crime'],
  ['top'],
  ['top', 'breaking'],
  ['sports'],
  ['top', 'crime'],
  ['technology'],
  ['business'],
];
final _pool = [
  for (var i = 0; i < 96; i++)
    (
      id: 'a${i.toString().padLeft(3, '0')}',
      categories: _combos[i % _combos.length],
      country: i.isEven ? 'india' : 'usa',
    ),
];
const _saved = ['top', 'sports'];

typedef _Req = Map<String, String>;

/// `GET /api/v2/home` stand-in with the backend contract: explicit categories
/// are OR, location is AND, category omitted → saved prefs, filter before paging.
class _FakeBackend {
  final List<_Req> requests = [];
  final Map<String, Completer<void>> gates = {};
  List<Map<String, dynamic>> inject = [];

  Future<V2FeedPage> call({
    required int page,
    required int limit,
    required String language,
    required HomeFilterState filter,
  }) async {
    final q = filter.toQueryParameters(
      language: language,
      page: page,
      limit: limit,
    );
    requests.add(q);
    final gate = gates[q['category'] ?? '-'];
    if (gate != null) await gate.future;

    final explicit = q['category']?.split(',');
    final source = explicit != null ? 'explicit' : 'saved_preferences';
    final active = explicit ?? _saved;
    final matching = _pool.where((a) {
      if (!a.categories.any(active.contains)) return false;
      if (q['country'] != null && a.country != q['country']) return false;
      return true;
    }).toList();
    final start = (page - 1) * limit;
    final slice = matching.skip(start).take(limit).toList();
    final items = [
      for (final a in slice)
        {
          'articleId': a.id,
          'title': 'Story ${a.id}',
          'category': [
            for (final c in a.categories) {'id': 'id-$c', 'name': c},
          ],
          'regions': {
            'countries': [a.country],
          },
        },
      ...inject,
    ];
    return V2FeedItemMapper.parseEnvelope({
      'success': true,
      'data': {
        'items': items,
        'page': page,
        'limit': limit,
        'hasNextPage': start + limit < matching.length,
        'filters': {
          'categorySource': source,
          'categories': [
            for (final c in active) {'id': 'id-$c', 'name': c, 'slug': c},
          ],
        },
      },
    });
  }
}

class _NoMetadata extends V2HomeMetadataApi {
  @override
  Future<List<V2CategoryOption>> fetchCategories() async => const [];
}

class _Rig {
  _Rig() {
    filters = V2HomeFilterController(metadataApi: _NoMetadata());
    reader = V2ReaderController(
      newsLanguageCode: () => 'en',
      appliedRegion: () => const SavedRegion(),
      homeFilter: () => filters.requestFilter,
      homeLoader: backend.call,
    );
  }

  final backend = _FakeBackend();
  late final V2HomeFilterController filters;
  late final V2ReaderController reader;

  /// Same wiring as `V2ReaderHome._onCategoryTapped`.
  Future<void> tap(String slug) {
    filters.toggleCategory(slug);
    return reader.refresh();
  }

  Future<void> select(List<String> slugs) async {
    for (final s in slugs) {
      filters.toggleCategory(s);
    }
    await reader.refresh();
  }

  Future<void> loadMore() async {
    reader.unawaitedLoadMore();
    await _settle();
  }

  List<NewsArticle> get shown => reader.state.articles;
  _Req get last => backend.requests.last;
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

bool _matches(NewsArticle a, List<String> selected) =>
    (a.category ?? const <String>[]).any(selected.contains);

void _expectAllMatch(List<NewsArticle> articles, List<String> selected) {
  expect(articles, isNotEmpty);
  for (final a in articles) {
    expect(_matches(a, selected), isTrue,
        reason: '${a.articleId} ${a.category} not in $selected');
  }
}

const _bbc = ['breaking', 'business', 'crime'];

/// Slug keys of the displayed feed (ids are also present by design).
Set<String> _slugKeys(V2ReaderController reader) =>
    reader.displayedCategoryKeys.where((k) => !k.startsWith('id-')).toSet();

void main() {
  group('explicit category filter correctness', () {
    test('single category shows only matching articles', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.tap('business');
      expect(rig.last['category'], 'business');
      _expectAllMatch(rig.shown, ['business']);
    });

    test('breaking + business + crime: request keeps all three, feed matches',
        () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.select(_bbc);
      expect(rig.last['category'], 'breaking,business,crime');
      _expectAllMatch(rig.shown, _bbc);
    });

    test('Top-only articles are never shown for breaking + business + crime',
        () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.select(_bbc);
      await rig.loadMore();
      expect(
        rig.shown.where((a) => a.category!.length == 1 && a.category!.first == 'top'),
        isEmpty,
      );
    });

    test('Breaking + Top article stays when Breaking is selected', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.tap('breaking');
      expect(
        rig.shown.any((a) => a.category!.contains('top')),
        isTrue,
        reason: 'multi-category stories that match Breaking are valid',
      );
      _expectAllMatch(rig.shown, ['breaking']);
    });

    test('saved preferences never merge with an explicit filter', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      expect(rig.last.containsKey('category'), isFalse);
      await rig.select(['business', 'crime']);
      expect(rig.last['category'], 'business,crime');
      expect(_slugKeys(rig.reader), {'business', 'crime'});
      expect(
        V2EffectiveHomeFilter.forRequest(rig.filters.committed)
            .selectedCategorySlugs,
        ['business', 'crime'],
      );
      _expectAllMatch(rig.shown, ['business', 'crime']);
    });

    test('clearing categories restores saved/default behavior', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.select(_bbc);
      expect(rig.filters.clearCategories(), isTrue);
      await rig.reader.refresh();
      expect(rig.last.containsKey('category'), isFalse);
      expect(_slugKeys(rig.reader), {'top', 'sports'});
    });
  });

  group('pagination / refresh / location', () {
    test('pages 1, 2, 3 all carry breaking + business + crime', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.select(_bbc);
      await rig.loadMore();
      await rig.loadMore();
      final pages = rig.backend.requests
          .where((r) => r['category'] == 'breaking,business,crime')
          .map((r) => r['page'])
          .toList();
      expect(pages, ['1', '2', '3']);
      expect(rig.reader.state.page, 3);
      _expectAllMatch(rig.shown, _bbc);
      final ids = rig.shown.map((a) => a.articleId).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
    });

    test('refresh keeps the explicit category filter', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.select(_bbc);
      await rig.reader.refresh();
      expect(rig.last['category'], 'breaking,business,crime');
      expect(rig.last['page'], '1');
      _expectAllMatch(rig.shown, _bbc);
    });

    test('category + location is AND', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      rig.filters.apply(
        rig.filters.committed.copyWith(
          selectedCategorySlugs: _bbc,
          country: 'india',
        ),
      );
      await rig.reader.refresh();
      expect(rig.last['category'], 'breaking,business,crime');
      expect(rig.last['country'], 'india');
      _expectAllMatch(rig.shown, _bbc);
    });
  });

  group('stale data', () {
    test('rapid category changes never show articles of an older selection',
        () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      final slow = Completer<void>();
      rig.backend.gates['business'] = slow;
      final first = rig.tap('business');
      await _settle();
      final second = rig.tap('crime');
      await _settle();
      slow.complete();
      await Future.wait([first, second]);
      await _settle();
      expect(rig.last['category'], 'business,crime');
      _expectAllMatch(rig.shown, ['business', 'crime']);
      expect(_slugKeys(rig.reader), {'business', 'crime'});
    });

    test('old unfiltered feed is fully replaced by the filtered feed', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      await rig.loadMore();
      expect(rig.shown.any((a) => a.category!.join() == 'top'), isTrue,
          reason: 'default feed contains Top-only stories');
      await rig.select(_bbc);
      expect(rig.reader.state.page, 1);
      expect(rig.reader.state.index, 0);
      _expectAllMatch(rig.shown, _bbc);
    });

    test('empty filtered result stays empty, no Top/default fallback',
        () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      expect(rig.shown, isNotEmpty);
      await rig.tap('world');
      expect(rig.reader.state.status, V2ReaderStatus.empty);
      expect(rig.shown, isEmpty);
      expect(rig.last['category'], 'world');
    });
  });

  group('response invariant + card badge', () {
    test('response invariant flags a Top-only item in an explicit response',
        () async {
      final rig = _Rig();
      rig.backend.inject = [
        {
          'articleId': 'D',
          'title': 'Top only',
          'category': [
            {'id': 'id-top', 'name': 'top'},
          ],
        },
      ];
      final page = await rig.backend.call(
        page: 1,
        limit: 4,
        language: 'en',
        filter: const HomeFilterState(selectedCategorySlugs: _bbc),
      );
      expect(V2HomeCategoryDebug.unmatchedArticleIds(page), ['D']);

      rig.backend.inject = [];
      final clean = await rig.backend.call(
        page: 1,
        limit: 20,
        language: 'en',
        filter: const HomeFilterState(selectedCategorySlugs: _bbc),
      );
      expect(V2HomeCategoryDebug.unmatchedArticleIds(clean), isEmpty);
    });

    test('matchKeys cover slug, name and id; empty for the default feed', () {
      final filters = V2HomeCategoryFilters.parse({
        'categorySource': 'explicit',
        'categories': [
          {'id': '6ab10e01a5abc256076ab63b', 'name': 'Top Stories', 'slug': 'top-stories'},
        ],
      })!;
      expect(filters.matchKeys,
          containsAll(['top-stories', '6ab10e01a5abc256076ab63b']));
      expect(
        V2HomeCategoryFilters.parse({'categorySource': 'default'})!.matchKeys,
        isEmpty,
      );
    });

    test('badge names the selected category, not the first stored tag', () {
      final keys = {'breaking', 'business', 'crime'};
      expect(v2HomeBadgeCategory(['top', 'business'], keys), 'business');
      expect(v2HomeBadgeCategory(['top', 'breaking'], keys), 'breaking');
      expect(v2HomeBadgeCategory(['Crime'], keys), 'Crime');
      expect(v2HomeBadgeCategory(['top', 'business'], const {}), 'top');
      expect(v2HomeBadgeCategory(const [], keys), isNull);
    });

    testWidgets('filtered card shows BUSINESS for a top+business story',
        (tester) async {
      Widget page(Set<String> keys) => MaterialApp(
            home: Scaffold(
              body: V2ArticlePage(
                article: NewsArticle(
                  articleId: 'x',
                  newsId: 'x',
                  title: 'LNG Train Debuts in Ahmedabad',
                  category: const ['top', 'business'],
                ),
                cutsLabel: 'NewsOn Cut',
                index: 0,
                total: 1,
                bookmarked: false,
                onBookmark: () {},
                onShare: () {},
                onViewFullArticle: () {},
                onPrevious: () {},
                onNext: () {},
                showAdSlot: false,
                activeCategoryKeys: keys,
              ),
            ),
          );
      await tester.pumpWidget(page({'breaking', 'business', 'crime'}));
      expect(find.text('BUSINESS'), findsOneWidget);
      expect(find.text('TOP'), findsNothing);

      await tester.pumpWidget(page(const {}));
      expect(find.text('TOP'), findsOneWidget);
    });

    test('controller exposes the categories of the displayed feed', () async {
      final rig = _Rig();
      await rig.reader.loadInitial();
      expect(_slugKeys(rig.reader), {'top', 'sports'});
      await rig.select(_bbc);
      expect(_slugKeys(rig.reader), _bbc.toSet());
    });
  });

  test('V2-only: no V1 category endpoint or fallback in the Home path', () {
    for (final path in [
      'lib/features/home_v2/data/v2_home_api.dart',
      'lib/features/home_v2/domain/v2_category_badge.dart',
      'lib/features/home_v2/presentation/v2_reader_controller.dart',
      'lib/features/home_v2/presentation/v2_home_filter_controller.dart',
      'lib/features/home_v2/presentation/widgets/v2_article_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('/api/v1'), isFalse, reason: path);
      expect(src.contains('getNewsByCategory'), isFalse, reason: path);
      expect(src.contains('useV2Host: false'), isFalse, reason: path);
    }
    final api = File('lib/features/home_v2/data/v2_home_api.dart')
        .readAsStringSync();
    expect(api.contains("path = '/api/v2/home'"), isTrue);
  });
}
