import '../../../data/models/category_model.dart';
import '../../../data/models/news_article.dart';

/// Immutable snapshot of V2 Home section presentation state.
class HomeState {
  const HomeState({
    this.breaking = const [],
    this.cuts = const [],
    this.latest = const [],
    this.forYou = const [],
    this.exploreCategories = const [],
    this.selectedExploreCategory,
    this.isRefreshing = false,
    this.isLoadingMoreLatest = false,
    this.latestPage = 1,
    this.breakingError,
    this.cutsError,
    this.latestError,
    this.forYouError,
    this.categoriesError,
    this.forYouVisible = false,
    this.updatedAt,
  });

  final List<NewsArticle> breaking;
  final List<NewsArticle> cuts;
  final List<NewsArticle> latest;
  final List<NewsArticle> forYou;
  final List<CategoryModel> exploreCategories;
  final CategoryModel? selectedExploreCategory;

  final bool isRefreshing;
  final bool isLoadingMoreLatest;
  final int latestPage;

  final String? breakingError;
  final String? cutsError;
  final String? latestError;
  final String? forYouError;
  final String? categoriesError;

  /// True when For You section should render (has useful data).
  final bool forYouVisible;

  final DateTime? updatedAt;

  HomeState copyWith({
    List<NewsArticle>? breaking,
    List<NewsArticle>? cuts,
    List<NewsArticle>? latest,
    List<NewsArticle>? forYou,
    List<CategoryModel>? exploreCategories,
    CategoryModel? selectedExploreCategory,
    bool clearSelectedExploreCategory = false,
    bool? isRefreshing,
    bool? isLoadingMoreLatest,
    int? latestPage,
    String? breakingError,
    String? cutsError,
    String? latestError,
    String? forYouError,
    String? categoriesError,
    bool clearBreakingError = false,
    bool clearCutsError = false,
    bool clearLatestError = false,
    bool clearForYouError = false,
    bool clearCategoriesError = false,
    bool? forYouVisible,
    DateTime? updatedAt,
  }) {
    return HomeState(
      breaking: breaking ?? this.breaking,
      cuts: cuts ?? this.cuts,
      latest: latest ?? this.latest,
      forYou: forYou ?? this.forYou,
      exploreCategories: exploreCategories ?? this.exploreCategories,
      selectedExploreCategory: clearSelectedExploreCategory
          ? null
          : (selectedExploreCategory ?? this.selectedExploreCategory),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMoreLatest: isLoadingMoreLatest ?? this.isLoadingMoreLatest,
      latestPage: latestPage ?? this.latestPage,
      breakingError:
          clearBreakingError ? null : (breakingError ?? this.breakingError),
      cutsError: clearCutsError ? null : (cutsError ?? this.cutsError),
      latestError: clearLatestError ? null : (latestError ?? this.latestError),
      forYouError: clearForYouError ? null : (forYouError ?? this.forYouError),
      categoriesError: clearCategoriesError
          ? null
          : (categoriesError ?? this.categoriesError),
      forYouVisible: forYouVisible ?? this.forYouVisible,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
