import 'package:flutter/foundation.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/news_article.dart';
import '../../../providers/for_you_provider.dart';
import '../../../providers/news_provider.dart';
import '../domain/explore_category_picker.dart';
import '../domain/home_deduper.dart';
import 'home_state.dart';

/// Coordinates V2 Home section loads with error isolation and dedupe.
///
/// Uses existing [NewsProvider] / [ForYouProvider] — does not replace them.
class HomeController extends ChangeNotifier {
  HomeController({
    required NewsProvider newsProvider,
    required ForYouProvider forYouProvider,
  })  : _news = newsProvider,
        _forYou = forYouProvider;

  final NewsProvider _news;
  final ForYouProvider _forYou;

  HomeState _state = const HomeState();
  HomeState get state => _state;

  bool _refreshInFlight = false;
  bool _loadMoreInFlight = false;
  Set<String>? _preferredCategoryIds;

  void setPreferredCategoryIds(Set<String>? ids) {
    _preferredCategoryIds = ids;
  }

  /// Initial / soft load — sections fail independently.
  Future<void> loadInitial() async {
    await Future.wait([
      _loadBreaking(),
      _loadCategories(),
      _loadTodayAndCuts(),
      _loadForYou(),
    ]);
    _rebuildDerived();
  }

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    _set(_state.copyWith(isRefreshing: true));
    try {
      await Future.wait([
        _loadBreaking(force: true),
        _loadCategories(),
        _loadTodayAndCuts(force: true),
        _loadForYou(),
      ]);
      _rebuildDerived();
      _set(_state.copyWith(
        isRefreshing: false,
        latestPage: 1,
        clearSelectedExploreCategory: true,
        updatedAt: DateTime.now(),
      ));
    } finally {
      _refreshInFlight = false;
      if (_state.isRefreshing) {
        _set(_state.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> loadMoreLatest() async {
    if (_loadMoreInFlight || _refreshInFlight) return;
    if (_state.selectedExploreCategory != null) return;

    _loadMoreInFlight = true;
    _set(_state.copyWith(isLoadingMoreLatest: true));
    try {
      final next = _state.latestPage + 1;
      await _news.fetchNewsByDate(DateTime.now(), limit: 20, page: next);
      _set(_state.copyWith(latestPage: next));
      _rebuildDerived();
    } catch (e) {
      _set(_state.copyWith(latestError: e.toString()));
    } finally {
      _loadMoreInFlight = false;
      _set(_state.copyWith(isLoadingMoreLatest: false));
    }
  }

  Future<void> selectExploreCategory(CategoryModel? category) async {
    if (category == null) {
      _set(_state.copyWith(clearSelectedExploreCategory: true));
      _rebuildDerived(useCategoryNews: false);
      return;
    }

    _set(_state.copyWith(selectedExploreCategory: category));
    try {
      await _news.fetchCategoryNews(
        category.name,
        limit: 20,
        date: DateTime.now(),
        forceNetwork: true,
      );
      _rebuildDerived(useCategoryNews: true);
    } catch (e) {
      _set(_state.copyWith(latestError: e.toString()));
    }
  }

  Future<void> onRegionApplied() async {
    await refresh();
  }

  Future<void> onNewsLanguageChanged() async {
    await refresh();
  }

  Future<void> _loadBreaking({bool force = false}) async {
    try {
      await _news.fetchBreakingNews(limit: 10, forceNetwork: force);
      _set(_state.copyWith(clearBreakingError: true));
    } catch (e) {
      _set(_state.copyWith(breakingError: e.toString()));
    }
  }

  Future<void> _loadCategories() async {
    try {
      await _news.fetchCategories();
      final focused = ExploreCategoryPicker.pickFocused(
        _news.categories,
        preferredIds: _preferredCategoryIds,
      );
      _set(_state.copyWith(
        exploreCategories: focused,
        clearCategoriesError: true,
      ));
    } catch (e) {
      _set(_state.copyWith(categoriesError: e.toString()));
    }
  }

  Future<void> _loadTodayAndCuts({bool force = false}) async {
    try {
      await _news.fetchNewsByDate(
        DateTime.now(),
        limit: 20,
        page: 1,
        forceNetwork: force,
      );
      _set(_state.copyWith(
        latestPage: 1,
        clearCutsError: true,
        clearLatestError: true,
      ));
    } catch (e) {
      _set(_state.copyWith(
        cutsError: e.toString(),
        latestError: e.toString(),
      ));
    }
  }

  Future<void> _loadForYou() async {
    try {
      if (_forYou.requiresSignIn) {
        _set(_state.copyWith(
          forYou: const [],
          forYouVisible: false,
          clearForYouError: true,
        ));
        return;
      }
      await _forYou.refresh(limit: 10);
      final visible = _forYou.hasArticles;
      _set(_state.copyWith(
        forYou: List<NewsArticle>.from(_forYou.articles),
        forYouVisible: visible,
        clearForYouError: true,
        forYouError: visible ? null : _forYou.error,
      ));
    } catch (e) {
      // Hide broken empty For You — keep Home usable.
      _set(_state.copyWith(
        forYou: const [],
        forYouVisible: false,
        forYouError: e.toString(),
      ));
    }
  }

  void _rebuildDerived({bool useCategoryNews = false}) {
    final breaking = List<NewsArticle>.from(_news.breakingNews.take(10));
    final today =
        _news.todayNews.isNotEmpty ? _news.todayNews : _news.articles;

    final featuredIds = HomeDeduper.idsOf(breaking);
    final cutsSource = HomeDeduper.excludeIds(today, featuredIds);
    final cuts = HomeDeduper.preferCuts(cutsSource);
    featuredIds.addAll(HomeDeduper.idsOf(cuts));

    List<NewsArticle> latest;
    if (useCategoryNews || _state.selectedExploreCategory != null) {
      latest = HomeDeduper.excludeIds(_news.categoryNews, featuredIds);
    } else {
      latest = HomeDeduper.excludeIds(today, featuredIds);
    }

    var forYou = const <NewsArticle>[];
    var forYouVisible = false;
    if (!_forYou.requiresSignIn && _forYou.hasArticles) {
      forYou = HomeDeduper.excludeIds(_forYou.articles, featuredIds);
      forYouVisible = forYou.isNotEmpty;
    }

    _set(_state.copyWith(
      breaking: breaking,
      cuts: cuts,
      latest: latest,
      forYou: forYou,
      forYouVisible: forYouVisible,
      updatedAt: DateTime.now(),
    ));
  }

  void _set(HomeState next) {
    _state = next;
    notifyListeners();
  }
}
