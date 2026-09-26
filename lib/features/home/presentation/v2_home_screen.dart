import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routing/v2_routes.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../data/services/user_service.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/for_you_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../screens/category_selection/category_selection_screen.dart';
import '../../news/domain/news_summary.dart';
import 'home_controller.dart';
import 'widgets/breaking_news_section.dart';
import 'widgets/category_explorer.dart';
import 'widgets/for_you_section.dart';
import 'widgets/home_ad_slot.dart';
import 'widgets/home_header.dart';
import 'widgets/latest_news_section.dart';
import 'widgets/news_cuts_section.dart';

/// Production V2 Home composition:
/// Breaking → NewsOn Cuts → Explore → Latest → For You
class V2HomeScreen extends StatefulWidget {
  const V2HomeScreen({
    super.key,
    this.onOpenForYouTab,
  });

  final VoidCallback? onOpenForYouTab;

  @override
  State<V2HomeScreen> createState() => _V2HomeScreenState();
}

class _V2HomeScreenState extends State<V2HomeScreen> {
  late final HomeController _controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _latestKey = GlobalKey();
  final GlobalKey _forYouKey = GlobalKey();
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.ensureSessionStarted();
    _controller = HomeController(
      newsProvider: context.read<NewsProvider>(),
      forYouProvider: context.read<ForYouProvider>(),
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    final regionProvider = context.read<RegionProvider>();
    if (!regionProvider.isInitialized) {
      await regionProvider.initialize();
    }
    if (!mounted) return;
    context.read<NewsProvider>().setSavedRegion(regionProvider.appliedRegion);

    try {
      final userData = UserService().getUserData();
      final raw = userData?['category'];
      if (raw is List && raw.isNotEmpty) {
        final ids = raw
            .where((id) => id != null)
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        if (ids.isNotEmpty) {
          _controller.setPreferredCategoryIds(ids);
        }
      }
    } catch (_) {}

    await _controller.loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _controller.loadMoreLatest();
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onRegionChanged() async {
    final region = context.read<RegionProvider>().appliedRegion;
    context.read<NewsProvider>().setSavedRegion(region);
    await _controller.onRegionApplied();
  }

  Future<void> _openArticle(
    NewsArticle article,
    List<NewsArticle> list,
    int index,
  ) async {
    await AnalyticsService.instance.newsOpen(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
    if (article.newsOnCutText != null) {
      await AnalyticsService.instance.summaryView(
        newsId: article.analyticsNewsId,
        v2Only: true,
      );
    }
    if (!mounted) return;
    await V2Routes.openArticle(
      context,
      article: article,
      articles: list,
      initialIndex: index,
    );
  }

  Future<void> _bookmark(NewsArticle article) async {
    await context.read<BookmarkProvider>().toggleBookmarkV2(article);
    await AnalyticsService.instance.bookmark(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
  }

  Future<void> _share(NewsArticle article) async {
    await NewsShareService.shareArticle(article, v2: true);
    await InteractionService().trackShare(article);
    await AnalyticsService.instance.share(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<RemoteConfigProvider>().config;
    final bookmarks = context.watch<BookmarkProvider>();
    final news = context.watch<NewsProvider>();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final showBreaking = config.breakingNewsEnabled;

        return Column(
          children: [
            V2HomeHeader(
              onRegionChanged: _onRegionChanged,
              onNewsLanguageChanged: () => _controller.onNewsLanguageChanged(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _controller.refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (showBreaking)
                      SliverToBoxAdapter(
                        child: BreakingNewsSection(
                          articles: state.breaking,
                          error: state.breakingError,
                          onRetry: () => _controller.loadInitial(),
                          autoScroll:
                              !MediaQuery.disableAnimationsOf(context),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: NewsCutsSection(
                        articles: state.cuts,
                        config: config,
                        isBookmarked: bookmarks.isBookmarked,
                        isLoading: news.isLoadingToday && state.cuts.isEmpty,
                        error: state.cutsError,
                        onRetry: () => _controller.refresh(),
                        onOpen: (a, i) => _openArticle(a, state.cuts, i),
                        onBookmark: _bookmark,
                        onShare: _share,
                      ),
                    ),
                    const SliverToBoxAdapter(child: HomeAdSlot()),
                    SliverToBoxAdapter(
                      child: CategoryExplorer(
                        categories: state.exploreCategories,
                        selected: state.selectedExploreCategory,
                        error: state.categoriesError,
                        onLatestTap: () {
                          _controller.selectExploreCategory(null);
                          _scrollTo(_latestKey);
                        },
                        onForYouTap: () {
                          if (state.forYouVisible) {
                            _scrollTo(_forYouKey);
                          } else {
                            widget.onOpenForYouTab?.call();
                          }
                        },
                        onCategorySelected: (c) async {
                          await _controller.selectExploreCategory(c);
                          _scrollTo(_latestKey);
                        },
                        onExploreAll: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CategorySelectionScreen(
                                useV2Catalog: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: _latestKey,
                        child: LatestNewsSection(
                          articles: state.latest,
                          title: state.selectedExploreCategory != null
                              ? state.selectedExploreCategory!.name
                              : LocalizationHelper.v2Latest(context),
                          isBookmarked: bookmarks.isBookmarked,
                          isLoading:
                              news.isLoadingToday && state.latest.isEmpty,
                          isLoadingMore: state.isLoadingMoreLatest,
                          error: state.latestError,
                          onRetry: () => _controller.refresh(),
                          onOpen: (a, i) => _openArticle(a, state.latest, i),
                          onBookmark: _bookmark,
                          onShare: _share,
                        ),
                      ),
                    ),
                    if (state.forYouVisible)
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _forYouKey,
                          child: ForYouSection(
                            articles: state.forYou,
                            isBookmarked: bookmarks.isBookmarked,
                            onBookmark: _bookmark,
                            onShare: _share,
                            onViewAll: widget.onOpenForYouTab,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
