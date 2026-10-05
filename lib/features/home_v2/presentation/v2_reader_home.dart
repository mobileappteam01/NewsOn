import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/v2_feature_flags.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../features/news/domain/news_summary.dart';
import '../../article_feedback/presentation/v2_article_feedback_coordinator.dart';
import '../../../features/news_detail/presentation/v2_article_detail_screen.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../data/v2_home_api.dart';
import '../domain/v2_effective_categories.dart';
import 'v2_home_filter_controller.dart';
import 'v2_news_text_scale.dart';
import 'v2_reader_controller.dart';
import 'v2_reader_ad_placement.dart';
import 'v2_reader_display_page.dart';
import 'v2_reader_demo_pages.dart';
import 'v2_reader_page_cache.dart';
import 'v2_reader_pager_session.dart';
import 'widgets/v2_article_image.dart';
import 'widgets/v2_article_page.dart';
import 'widgets/v2_reader_ad_page.dart';
import 'widgets/v2_home_category_bar.dart';
import 'widgets/v2_home_filter_sheet.dart';
import 'widgets/v2_page_turn.dart';
import 'widgets/v2_vintage_paper_background.dart';

/// V2 one-article-at-a-time reader home (flag-gated).
class V2ReaderHome extends StatefulWidget {
  const V2ReaderHome({super.key, this.onOpenForYouTab});

  final VoidCallback? onOpenForYouTab;

  @override
  State<V2ReaderHome> createState() => V2ReaderHomeState();
}

class V2ReaderHomeState extends State<V2ReaderHome>
    with AutomaticKeepAliveClientMixin {
  late final V2ReaderController _controller;
  late final V2HomeFilterController _filters;
  late final V2HomeApi _homeApi;
  late final V2ArticleFeedbackCoordinator _feedback;
  late final PageFlipController _pageFlipController;
  bool _bootstrapped = false;
  String? _lastSummaryTrackedId;
  final V2ReaderPagerSession _pager = V2ReaderPagerSession();
  bool _bookBuilt = false;
  Timer? _addedPagesRetry;
  bool _prefetchScheduled = false;
  final V2ReaderPageCache _pages = V2ReaderPageCache();

  /// A vertical drag (pull-to-refresh or article scroll) is in progress;
  /// rebuilding the book now would drop the scrollable under the finger.
  bool _verticalDragActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.ensureSessionStarted();
    _pageFlipController = PageFlipController();
    _filters = V2HomeFilterController();
    _homeApi = V2HomeApi();
    _feedback = V2ArticleFeedbackCoordinator();
    _controller = V2ReaderController(
      newsLanguageCode: () => context.read<LanguageProvider>().newsLanguageCode,
      appliedRegion: () => context.read<RegionProvider>().appliedRegion,
      homeFilter: () => _filters.requestFilter,
      homeLoader:
          ({
            required page,
            required limit,
            required language,
            required filter,
          }) => _homeApi.fetch(
            filter: filter,
            language: language,
            page: page,
            limit: limit,
          ),
      notInterested: _feedback.api.markNotInterested,
    );
    _controller.addListener(_onControllerTick);
    V2CategoryPreferenceResolver.revision.addListener(
      _onSavedPreferencesChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Public Home re-tap / intentional refresh entry point.
  Future<void> refreshHome() => _controller.refresh(keepVisible: true);

  void _onControllerTick() {
    final change = _pager.sync(
      _controller,
      adsEnabled: V2ReaderAdPlacement.adsEnabled,
      turning:
          _bookBuilt && V2PageTurn.isTurning(_pageFlipController) ||
          _verticalDragActive,
    );
    switch (change) {
      case V2PagerChange.newFeed:
        if (_controller.state.status == V2ReaderStatus.ready) {
          _applyDemoPagesIfNeeded();
        }
      case V2PagerChange.feedMerged:
      case V2PagerChange.feedEdited:
        _onArticleVisible();
      case V2PagerChange.pagesDeferred:
        _addedPagesRetry ??= Timer(
          const Duration(milliseconds: 200),
          _retryAddedPages,
        );
      case V2PagerChange.pagesAdded:
      case V2PagerChange.none:
        break;
    }
  }

  /// Adds load-more pages held back by a page turn once the turn is over.
  void _retryAddedPages() {
    _addedPagesRetry = null;
    if (!mounted) return;
    setState(_onControllerTick);
  }

  /// Pads the in-memory reader list to 3 pages when the demo dart-define is on.
  void _applyDemoPagesIfNeeded() {
    if (!V2FeatureFlags.readerDemoPages()) return;
    final current = _controller.state.articles;
    final expanded = expandV2ReaderDemoPages(current);
    if (expanded.length == current.length) return;
    _controller.replaceArticlesForDisplay(expanded);
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;
    final region = context.read<RegionProvider>();
    if (!region.isInitialized) {
      await region.initialize();
    }
    if (!mounted) return;
    // Wait for preference awareness + server category sync before the first
    // Home request so we never flash an accidental empty constrained feed.
    await _filters.syncSavedPreferences();
    if (!mounted) return;
    await _controller.loadInitial();
    _onArticleVisible();
  }

  void _onSavedPreferencesChanged() {
    if (!mounted) return;
    unawaited(_reloadForPreferenceChange());
  }

  Future<void> _reloadForPreferenceChange() async {
    await _filters.syncSavedPreferences(forceCatalog: true);
    if (!mounted) return;
    // Clear is not required — request omits category so backend uses new prefs.
    // Keep any explicit temporary filter intact.
    await _controller.refresh();
  }

  Future<void> _openFilters() async {
    // Sheet seeds from temporary filter only — never from saved prefs.
    final draft = await showV2HomeFilterSheet(
      context,
      initial: _filters.committed,
    );
    if (!mounted || draft == null) return;
    _filters.apply(draft);
    await _controller.refresh();
  }

  void _onCategoryTapped(String slug) {
    _filters.toggleCategory(slug);
    unawaited(_controller.refresh());
  }

  void _onAllCategories() {
    if (_filters.clearCategories()) unawaited(_controller.refresh());
  }

  Future<void> _onPullToRefresh() => _controller.refresh();

  bool _trackVerticalDrag(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _verticalDragActive = true;
    } else if (notification is ScrollEndNotification) {
      _verticalDragActive = false;
    }
    return false;
  }

  @override
  void dispose() {
    _addedPagesRetry?.cancel();
    V2CategoryPreferenceResolver.revision.removeListener(
      _onSavedPreferencesChanged,
    );
    _controller.removeListener(_onControllerTick);
    _filters.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Records the article on screen now; the analytics calls and image
  /// prefetch run once no page turn is animating.
  void _onArticleVisible() {
    final article = _controller.state.current;
    if (article == null) return;
    final id = article.analyticsNewsId;
    final impression = _controller.markImpression(id);
    final summary =
        article.resolvedSummaryStatus == NewsSummaryStatus.available &&
        article.newsOnCutText != null &&
        _lastSummaryTrackedId != id;
    if (summary) _lastSummaryTrackedId = id;
    if (impression || summary) {
      SchedulerBinding.instance.scheduleTask<void>(() {
        if (impression) {
          final category =
              (article.category != null && article.category!.isNotEmpty)
              ? article.category!.first
              : null;
          AnalyticsService.instance.newsImpression(
            newsId: id,
            category: category,
            publisher: article.publisherDisplayName,
            v2Only: true,
          );
          AnalyticsService.instance.newsOpen(newsId: id, v2Only: true);
        }
        if (summary) {
          AnalyticsService.instance.summaryView(newsId: id, v2Only: true);
        }
      }, Priority.idle);
    }
    if (!_prefetchScheduled) {
      _prefetchScheduled = true;
      SchedulerBinding.instance.scheduleTask<void>(() {
        _prefetchScheduled = false;
        if (mounted) _prefetchNeighbors();
      }, Priority.idle);
    }
  }

  void _prefetchNeighbors() {
    final state = _controller.state;
    final i = state.index;
    final idxs = <int>{
      i,
      if (i - 1 >= 0) i - 1,
      if (i + 1 < state.articles.length) i + 1,
      if (i + 2 < state.articles.length) i + 2,
    };
    for (final idx in idxs) {
      final url = state.articles[idx].imageUrl?.trim();
      if (url == null || url.isEmpty) continue;
      precacheImage(V2ArticleImage.provider(url), context);
    }
  }

  Future<void> _openFullArticle(NewsArticle article) async {
    if (!mounted) return;
    // Open V2 detail by articleId — screen fetches GET /api/v2/article/{id}.
    // External publisher URL is a secondary action inside detail, not this CTA.
    final id = article.analyticsNewsId;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: '/v2/article/$id'),
        pageBuilder: (context, animation, secondaryAnimation) {
          return V2ArticleDetailScreen(articleId: id, seedArticle: article);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _toggleBookmark(NewsArticle article) async {
    try {
      await context.read<BookmarkProvider>().toggleBookmarkV2(article);
      await AnalyticsService.instance.bookmark(
        newsId: article.analyticsNewsId,
        v2Only: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationHelper.error(context, e.toString())),
        ),
      );
    }
  }

  Future<void> _openArticleMenu(NewsArticle article) =>
      _feedback.openMenu(context, article, hide: _controller.hideNotInterested);

  Future<void> _share(NewsArticle article) async {
    await NewsShareService.shareArticle(article, v2: true);
    await InteractionService().trackShare(article);
    await AnalyticsService.instance.share(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
  }

  void _onDisplayPage(List<V2ReaderDisplayPage> pages, int pageIndex) {
    setState(() => _pager.displayIndex = pageIndex);
    final articleIndex = V2ReaderDisplayPages.articleIndexAt(pages, pageIndex);
    if (articleIndex != null && _controller.setIndex(articleIndex)) {
      _onArticleVisible();
    }
  }

  Future<void> _flipPrevious() async {
    final ok = await _pageFlipController.previousPage();
    if (!ok && mounted) {
      // Already on first visual page — keep controller in sync.
      _onArticleVisible();
    }
  }

  Future<void> _flipNext() async {
    final ok = await _pageFlipController.nextPage();
    if (!ok) {
      _controller.unawaitedLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final config = context.watch<RemoteConfigProvider>().config;
    final bookmarks = context.watch<BookmarkProvider>();
    final cutsLabel = V2FeatureFlags.cutsLabel(config);

    // Page turns notify [_controller]; only the reading body listens to it.
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: V2VintagePaperBackground(intensity: V2PaperIntensity.stage),
        ),
        Column(
          children: [
            ListenableBuilder(
              listenable: _filters,
              builder: (context, _) => V2HomeHeader(
                onOpenFilters: _openFilters,
                filtersActive: _filters.committed.hasSheetFilters,
                onNewsLanguageChanged: () => _controller.refresh(),
              ),
            ),
            ListenableBuilder(
              listenable: _filters,
              builder: (context, _) => V2HomeCategoryBar(
                categories: _filters.catalog,
                selectedSlugs: _filters.committed.selectedCategorySlugs,
                pending: _filters.catalogPending,
                failed: _filters.catalogFailed,
                onToggle: _onCategoryTapped,
                onSelectAll: _onAllCategories,
                onRetry: () => unawaited(_filters.reloadCatalog()),
              ),
            ),
            Expanded(child: _buildBody(bookmarks, cutsLabel)),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BookmarkProvider bookmarks, String cutsLabel) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _filters]),
      builder: (context, _) =>
          _buildBodyContent(_controller.state, bookmarks, cutsLabel),
    );
  }

  Widget _buildBodyContent(
    V2ReaderState state,
    BookmarkProvider bookmarks,
    String cutsLabel,
  ) {
    final filtered = _filters.committed.isActive;
    final loadError = filtered
        ? LocalizationHelper.v2FilterLoadError(context)
        : LocalizationHelper.v2ForYouLoadError(context);
    final Widget content;
    if (_controller.showingPreviousFeed) {
      // Articles on screen belong to the previous language/filter.
      content =
          _controller.refreshInFlight || state.status == V2ReaderStatus.loading
          ? _PendingFeedOverlay(
              child: _buildReadyBody(state, bookmarks, cutsLabel),
            )
          : _ErrorState(message: loadError, onRetry: _controller.refresh);
    } else {
      content = switch (state.status) {
        // Soft refresh: keep showing the last feed while a revalidation runs.
        V2ReaderStatus.idle || V2ReaderStatus.loading =>
          state.articles.isNotEmpty
              ? _buildReadyBody(state, bookmarks, cutsLabel)
              : const _LoadingState(),
        V2ReaderStatus.error =>
          state.articles.isNotEmpty
              ? _buildReadyBody(state, bookmarks, cutsLabel)
              : _ErrorState(message: loadError, onRetry: _controller.refresh),
        V2ReaderStatus.empty => _EmptyState(
          message: filtered
              ? LocalizationHelper.v2FilterNoResults(context)
              : LocalizationHelper.v2ForYouEmpty(context),
          onRetry: _controller.refresh,
        ),
        V2ReaderStatus.ready => _buildReadyBody(state, bookmarks, cutsLabel),
      };
    }

    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      notificationPredicate: v2ReaderPullNotificationPredicate,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: v2ReaderSuppressTopOverscroll,
        child: NotificationListener<ScrollNotification>(
          onNotification: _trackVerticalDrag,
          // A scroll view disposed mid-drag sends no ScrollEndNotification;
          // lifting the finger always ends the drag.
          child: Listener(
            onPointerUp: (_) => _verticalDragActive = false,
            onPointerCancel: (_) => _verticalDragActive = false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Clamping reports the full finger travel as overscroll, the
                  // same as the article's own scroll view, so the pull needed
                  // to refresh does not depend on which of the two handles it.
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: content,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyBody(
    V2ReaderState state,
    BookmarkProvider bookmarks,
    String cutsLabel,
  ) {
    final pages = V2ReaderDisplayPages.build(
      state.articles.length,
      adsEnabled: V2ReaderAdPlacement.adsEnabled,
    );
    final safeDisplay = pages.isEmpty
        ? 0
        : _pager.displayIndex.clamp(0, pages.length - 1);
    final articleIndex = V2ReaderDisplayPages.articleIndexAt(
      pages,
      safeDisplay,
    );
    final current = articleIndex == null ? null : state.articles[articleIndex];
    if (pages.isNotEmpty) _bookBuilt = true;
    _pages.prepare(_pager.epoch, pages.length);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: V2PageTurn(
            key: ValueKey('v2_turn_${_pager.epoch}'),
            controller: _pageFlipController,
            itemCount: pages.length,
            index: safeDisplay,
            canGoNext: safeDisplay < pages.length - 1 || state.hasMore,
            canGoPrevious: safeDisplay > 0,
            onIndexChanged: (pageIndex) => _onDisplayPage(pages, pageIndex),
            itemBuilder: (context, i) {
              final page = pages[i];
              if (page is V2ReaderAdDisplay) {
                return _pages.get(
                  i,
                  null,
                  page.slotIndex,
                  () => V2ReaderAdPage(slotIndex: page.slotIndex),
                );
              }
              final articlePage = page as V2ReaderArticleDisplay;
              final article = state.articles[articlePage.articleIndex];
              final bookmarked = bookmarks.isBookmarked(article);
              final canNext = i < pages.length - 1 || state.hasMore;
              final categoryKeys = _controller.displayedCategoryKeys;
              return _pages.get(
                i,
                article,
                (
                  articlePage.articleIndex,
                  state.total,
                  bookmarked,
                  canNext,
                  cutsLabel,
                  V2IdentityKey(categoryKeys),
                ),
                () => V2NewsTextScope(
                  child: V2ArticlePage(
                    article: article,
                    cutsLabel: cutsLabel,
                    index: articlePage.articleIndex,
                    total: state.total,
                    bookmarked: bookmarked,
                    onBookmark: () => _toggleBookmark(article),
                    onShare: () => _share(article),
                    onViewFullArticle: () => _openFullArticle(article),
                    onPrevious: _flipPrevious,
                    onNext: _flipNext,
                    canPrevious: i > 0,
                    canNext: canNext,
                    showAdSlot: false,
                    showHeroActions: false,
                    activeCategoryKeys: categoryKeys,
                  ),
                ),
              );
            },
          ),
        ),
        if (current != null)
          Positioned(
            top: 10,
            right: 18,
            child: Material(
              type: MaterialType.transparency,
              child: V2ReaderActionButtons(
                bookmarked: bookmarks.isBookmarked(current),
                onBookmark: () => _toggleBookmark(current),
                onShare: () => _share(current),
                onMore: () => _openArticleMenu(current),
              ),
            ),
          ),
      ],
    );
  }
}

/// Home pull-to-refresh listens to vertical scrolling at any depth: the pull
/// lands on the article's own scroll view whenever its text overflows the
/// page (long titles/summaries, large text scale) and on the body scroll
/// view otherwise. `RefreshIndicator` only starts at the top edge, so
/// scrolling back up inside an article never refreshes mid-gesture.
bool v2ReaderPullNotificationPredicate(ScrollNotification notification) =>
    notification.metrics.axis == Axis.vertical;

/// The refresh indicator replaces the top overscroll glow/stretch of both
/// scroll views; the bottom one is kept.
bool v2ReaderSuppressTopOverscroll(
  OverscrollIndicatorNotification notification,
) {
  if (notification.leading) notification.disallowIndicator();
  return false;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            LocalizationHelper.v2FilterLoading(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Previous feed dimmed and non-interactive while the new filter loads.
class _PendingFeedOverlay extends StatelessWidget {
  const _PendingFeedOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      key: const ValueKey('v2_home_pending_feed'),
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: ExcludeSemantics(child: child)),
        ColoredBox(
          color: theme.colorScheme.surface.withValues(alpha: 0.82),
          child: const _LoadingState(),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(LocalizationHelper.retry(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(LocalizationHelper.retry(context)),
            ),
          ],
        ),
      ),
    );
  }
}
