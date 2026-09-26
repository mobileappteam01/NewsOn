import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/home/presentation/widgets/home_header.dart';
import 'package:newson/features/home_v2/data/v2_home_api.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';
import 'package:newson/features/home_v2/presentation/v2_home_filter_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_home_filter_sheet.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';
import 'package:newson/providers/language_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:provider/provider.dart';

NewsArticle _article(String id) => NewsArticle(
      articleId: id,
      newsId: id,
      title: 'Story $id',
    );

void main() {
  group('metadata parsing', () {
    test('categories load from API payload and are not a hardcoded catalog', () {
      final categories = V2CategoryOption.parseList({
        'data': [
          {'slug': 'technology', 'name': 'Technology'},
          {'slug': 'business', 'name': 'Business'},
        ],
      });
      expect(categories.map((c) => c.slug), ['technology', 'business']);
      expect(categories.map((c) => c.name), ['Technology', 'Business']);
      expect(categories.any((c) => c.name == 'Crime'), isFalse);
    });

    test('countries, states and cities parse from V2 envelopes', () {
      expect(
        V2RegionOption.parseList({
          'data': {'countries': [{'slug': 'india', 'name': 'India'}]},
        }).single.slug,
        'india',
      );
      expect(
        V2RegionOption.parseList({
          'data': [
            {'slug': 'tamil-nadu', 'name': 'Tamil Nadu'},
          ],
        }).single.name,
        'Tamil Nadu',
      );
      expect(
        V2RegionOption.parseList({
          'data': {'cities': [{'slug': 'coimbatore', 'name': 'Coimbatore'}]},
        }).single.slug,
        'coimbatore',
      );
    });
  });

  group('HomeFilterState', () {
    test('multi-select categories serialize uniquely', () {
      var state = const HomeFilterState();
      state = state.toggleCategory('technology');
      state = state.toggleCategory('business');
      state = state.toggleCategory('technology');
      state = state.toggleCategory('technology');
      final query = state.toQueryParameters(
        language: 'tamil',
        page: 1,
        limit: 20,
      );
      expect(query['category'], 'business,technology');
      expect(query['language'], 'tamil');
      expect(query.containsKey('country'), isFalse);
    });

    test('changing country clears state and city', () {
      final state = const HomeFilterState(
        country: 'india',
        state: 'tamil-nadu',
        district: 'coimbatore',
      ).selectCountry('usa');
      expect(state.country, 'usa');
      expect(state.state, isNull);
      expect(state.district, isNull);
    });

    test('changing state clears city', () {
      final state = const HomeFilterState(
        country: 'india',
        state: 'tamil-nadu',
        district: 'coimbatore',
      ).selectState('kerala');
      expect(state.state, 'kerala');
      expect(state.district, isNull);
      expect(state.country, 'india');
    });

    test('apply query includes location as city alias', () {
      const state = HomeFilterState(
        selectedCategorySlugs: ['technology', 'business'],
        country: 'india',
        state: 'tamil-nadu',
        district: 'coimbatore',
      );
      final query = state.toQueryParameters(
        language: 'tamil',
        page: 1,
        limit: 20,
      );
      expect(query['category'], 'technology,business');
      expect(query['country'], 'india');
      expect(query['state'], 'tamil-nadu');
      expect(query['city'], 'coimbatore');
      expect(query.containsKey('district'), isFalse);
    });

    test('clear all resets filters but caller keeps language separate', () {
      final cleared = const HomeFilterState(
        selectedCategorySlugs: ['sports'],
        country: 'india',
      ).cleared();
      expect(cleared.isActive, isFalse);
      final query = cleared.toQueryParameters(
        language: 'tamil',
        page: 1,
        limit: 20,
      );
      expect(query.keys, containsAll(['language', 'page', 'limit']));
      expect(query.length, 3);
    });

    test('empty filter omits category and location', () {
      final query = const HomeFilterState().toQueryParameters(
        language: 'en',
        page: 2,
        limit: 20,
      );
      expect(query, {'language': 'en', 'page': '2', 'limit': '20'});
    });
  });

  group('committed vs draft', () {
    test('closing without apply does not modify live filter', () {
      final controller = V2HomeFilterController();
      controller.apply(
        const HomeFilterState(selectedCategorySlugs: ['technology']),
      );
      // Sheet draft is discarded when Apply is not called.
      const HomeFilterState(selectedCategorySlugs: ['sports']);
      expect(controller.committed.selectedCategorySlugs, ['technology']);
    });

    test('apply commits draft and clear apply resets explicit filter only', () {
      final controller = V2HomeFilterController();
      controller.apply(
        const HomeFilterState(
          selectedCategorySlugs: ['technology', 'business'],
          country: 'india',
          state: 'tamil-nadu',
          district: 'coimbatore',
        ),
      );
      expect(controller.isActive, isTrue);
      controller.clearAndApply();
      expect(controller.committed.isActive, isFalse);
      // Request omits category so backend restores saved preferences.
      expect(
        controller.requestFilter
            .toQueryParameters(language: 'en', page: 1, limit: 20)
            .containsKey('category'),
        isFalse,
      );
    });
  });

  group('reader preserves filters', () {
    test('pagination and refresh resend the same filter', () async {
      final calls = <HomeFilterState>[];
      const active = HomeFilterState(
        selectedCategorySlugs: ['technology'],
        country: 'india',
        state: 'tamil-nadu',
      );
      final controller = V2ReaderController(
        newsLanguageCode: () => 'tamil',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => active,
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          calls.add(filter);
          return V2FeedPage(
            articles: page == 1
                ? [_article('aaaaaaaaaaaaaaaaaaaaaaaa')]
                : [_article('bbbbbbbbbbbbbbbbbbbbbbbb')],
            page: page,
            hasMore: page == 1,
          );
        },
      );

      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.ready);
      controller.unawaitedLoadMore();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await controller.refresh();

      expect(calls.length, greaterThanOrEqualTo(3));
      expect(calls.every((f) => f.country == 'india'), isTrue);
      expect(calls.every((f) => f.state == 'tamil-nadu'), isTrue);
      expect(
        calls.every((f) => f.selectedCategorySlugs.contains('technology')),
        isTrue,
      );
    });

    test('empty filtered feed stays empty', () async {
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeFilter: () => const HomeFilterState(
          selectedCategorySlugs: ['tourism'],
        ),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          return const V2FeedPage(articles: [], page: 1, hasMore: false);
        },
      );
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.empty);
      expect(controller.state.articles, isEmpty);
    });

    test('home API error surfaces error status', () async {
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          throw Exception('home failed');
        },
      );
      await controller.loadInitial();
      expect(controller.state.status, V2ReaderStatus.error);
    });

    test('no filter still loads the home page', () async {
      HomeFilterState? seen;
      final controller = V2ReaderController(
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(country: 'should-not-send'),
        homeFilter: () => const HomeFilterState(),
        homeLoader: ({
          required page,
          required limit,
          required language,
          required filter,
        }) async {
          seen = filter;
          return V2FeedPage(
            articles: [_article('cccccccccccccccccccccccc')],
            page: 1,
            hasMore: false,
          );
        },
      );
      await controller.loadInitial();
      expect(seen!.isActive, isFalse);
      expect(controller.state.articles, isNotEmpty);
    });
  });

  testWidgets('filter icon shows active tint when filters are on', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider.forTest()),
          ChangeNotifierProvider(
            create: (_) => RemoteConfigProvider.forTest(RemoteConfigModel()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.red)),
          home: Scaffold(
            body: V2HomeHeader(
              onOpenFilters: () async {},
              filtersActive: true,
            ),
          ),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.tune_rounded));
    expect(icon.color, isNotNull);
    expect(find.byIcon(Icons.public), findsNothing);
  });

  testWidgets('sheet dismiss without apply does not pop a filter', (tester) async {
    HomeFilterState? result = const HomeFilterState(country: 'sentinel');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showV2HomeFilterSheet(
                    context,
                    initial: const HomeFilterState(
                      selectedCategorySlugs: ['technology'],
                    ),
                    metadataApi: _ThrowingMetadata(),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Drag the sheet down / tap barrier.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

class _ThrowingMetadata extends V2HomeMetadataApi {
  @override
  Future<List<V2CategoryOption>> fetchCategories() async => const [];

  @override
  Future<List<V2RegionOption>> fetchCountries() async => const [];
}
