import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/v2_feature_flags.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../features/news/domain/news_summary.dart';
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
import 'widgets/v2_article_page.dart';
import 'widgets/v2_reader_ad_page.dart';
import 'widgets/v2_home_filter_sheet.dart';
import 'widgets/v2_page_turn.dart';
import 'widgets/v2_vintage_paper_background.dart';

/// V2 one-article-at-a-time reader home (flag-gated).
class V2ReaderHome extends StatefulWidget {
  const V2ReaderHome({
    super.key,
    this.onOpenForYouTab,
  });

  final VoidCallback? onOpenForYouTab;

  @override
  State<V2ReaderHome> createState() => V2ReaderHomeState();
}

class V2ReaderHomeState extends State<V2ReaderHome>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final V2ReaderController _controller;
  late final V2HomeFilterController _filters;
  late final V2HomeApi _homeApi;
  late final PageFlipController _pageFlipController;
  bool _bootstrapped = false;
  String? _lastSummaryTrackedId;
  /// Bumped on full feed reload so TurnablePage resets without resetting on loadMore.
  int _feedEpoch = 0;
  int _displayIndex = 0;
  V2ReaderStatus? _lastStatus;
  DateTime? _lastResumeAt;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.ensureSessionStarted();
    _pageFlipController = PageFlipController();
    _filters = V2HomeFilterController();
    _homeApi = V2HomeApi();
    _controller = V2ReaderController(
      newsLanguageCode: () => context.read<LanguageProvider>().newsLanguageCode,
      appliedRegion: () => context.read<RegionProvider>().appliedRegion,
      homeFilter: () => _filters.requestFilter,
      homeLoader: ({
        required page,
        required limit,
        required language,
        required filter,
      }) =>
          _homeApi.fetch(
            filter: filter,
            language: language,
            page: page,
            limit: limit,
          ),
    );
    _controller.addListener(_onControllerTick);
    V2CategoryPreferenceResolver.revision
        .addListener(_onSavedPreferencesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Public Home re-tap / intentional refresh entry point.
  Future<void> refreshHome() => _controller.refresh(keepVisible: true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_bootstrapped || !mounted) return;
    final now = DateTime.now();
    final last = _lastResumeAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    if (_controller.refreshInFlight) return;
    _lastResumeAt = now;
    unawaited(_controller.refresh(keepVisible: false));
  }

  void _onControllerTick() {
    final status = _controller.state.status;
    if (_lastStatus == V2ReaderStatus.loading &&
        (status == V2ReaderStatus.ready || status == V2ReaderStatus.empty)) {
      _feedEpoch++;
      _displayIndex = 0;
      // Update before demo expand — replaceArticlesForDisplay notifies again.
      _lastStatus = status;
      if (status == V2ReaderStatus.ready) {
        _applyDemoPagesIfNeeded();
      }
      return;
    }
    _lastStatus = status;
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

  Future<void> _onPullToRefresh() => _controller.refresh();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    V2CategoryPreferenceResolver.revision
        .removeListener(_onSavedPreferencesChanged);
    _controller.removeListener(_onControllerTick);
    _filters.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onArticleVisible() {
    final article = _controller.state.current;
    if (article == null) return;
    final id = article.analyticsNewsId;
    if (_controller.markImpression(id)) {
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
    if (article.resolvedSummaryStatus == NewsSummaryStatus.available &&
        article.newsOnCutText != null &&
        _lastSummaryTrackedId != id) {
      _lastSummaryTrackedId = id;
      AnalyticsService.instance.summaryView(newsId: id, v2Only: true);
    }
    _prefetchNeighbors();
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
      precacheImage(CachedNetworkImageProvider(url), context);
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
          return V2ArticleDetailScreen(
            articleId: id,
            seedArticle: article,
          );
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

  Future<void> _share(NewsArticle article) async {
    await NewsShareService.shareArticle(article, v2: true);
    await InteractionService().trackShare(article);
    await AnalyticsService.instance.share(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
  }

  void _onDisplayPage(List<V2ReaderDisplayPage> pages, int pageIndex) {
    setState(() => _displayIndex = pageIndex);
    final articleIndex =
        V2ReaderDisplayPages.articleIndexAt(pages, pageIndex);
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

    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _filters]),
      builder: (context, _) {
        final state = _controller.state;
        return Stack(
          fit: StackFit.expand,
          children: [
            const V2VintagePaperBackground(
              intensity: V2PaperIntensity.stage,
            ),
            Column(
              children: [
                V2HomeHeader(
                  onOpenFilters: _openFilters,
                  filtersActive: _filters.isActive,
                  onNewsLanguageChanged: () => _controller.refresh(),
                ),
                Expanded(child: _buildBody(state, bookmarks, cutsLabel)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    V2ReaderState state,
    BookmarkProvider bookmarks,
    String cutsLabel,
  ) {
    final content = switch (state.status) {
      V2ReaderStatus.idle || V2ReaderStatus.loading => const _LoadingState(),
      V2ReaderStatus.error => _ErrorState(
          message: LocalizationHelper.v2ForYouLoadError(context),
          onRetry: _controller.refresh,
        ),
      V2ReaderStatus.empty => _EmptyState(
          message: _filters.hasExplicitCategories
              ? 'No news found for the selected filters'
              : LocalizationHelper.v2ForYouEmpty(context),
          onRetry: _controller.refresh,
        ),
      V2ReaderStatus.ready => _buildReadyBody(state, bookmarks, cutsLabel),
    };

    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: content,
            ),
          );
        },
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
        : _displayIndex.clamp(0, pages.length - 1);
    final articleIndex =
        V2ReaderDisplayPages.articleIndexAt(pages, safeDisplay);
    final current = articleIndex == null
        ? null
        : state.articles[articleIndex];
    return Stack(
      fit: StackFit.expand,
      children: [
        V2PageTurn(
          key: ValueKey('v2_turn_$_feedEpoch'),
          controller: _pageFlipController,
          itemCount: pages.length,
          index: safeDisplay,
          canGoNext: safeDisplay < pages.length - 1 || state.hasMore,
          canGoPrevious: safeDisplay > 0,
          onIndexChanged: (pageIndex) => _onDisplayPage(pages, pageIndex),
          itemBuilder: (context, i) {
            final page = pages[i];
            if (page is V2ReaderAdDisplay) {
              return V2ReaderAdPage(slotIndex: page.slotIndex);
            }
            final articlePage = page as V2ReaderArticleDisplay;
            final article = state.articles[articlePage.articleIndex];
            return V2NewsTextScope(
              child: V2ArticlePage(
                article: article,
                cutsLabel: cutsLabel,
                index: articlePage.articleIndex,
                total: state.total,
                bookmarked: bookmarks.isBookmarked(article),
                onBookmark: () => _toggleBookmark(article),
                onShare: () => _share(article),
                onViewFullArticle: () => _openFullArticle(article),
                onPrevious: _flipPrevious,
                onNext: _flipNext,
                canPrevious: i > 0,
                canNext: i < pages.length - 1 || state.hasMore,
                showAdSlot: false,
                showHeroActions: false,
              ),
            );
          },
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
              ),
            ),
          ),
      ],
    );
  }
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
            'Loading stories…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
