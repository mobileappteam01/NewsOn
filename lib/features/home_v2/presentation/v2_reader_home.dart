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
import 'v2_reader_controller.dart';
import 'v2_reader_demo_pages.dart';
import 'widgets/v2_article_page.dart';
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
  State<V2ReaderHome> createState() => _V2ReaderHomeState();
}

class _V2ReaderHomeState extends State<V2ReaderHome>
    with AutomaticKeepAliveClientMixin {
  late final V2ReaderController _controller;
  late final PageFlipController _pageFlipController;
  bool _bootstrapped = false;
  String? _lastSummaryTrackedId;
  /// Bumped on full feed reload so TurnablePage resets without resetting on loadMore.
  int _feedEpoch = 0;
  V2ReaderStatus? _lastStatus;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.ensureSessionStarted();
    _pageFlipController = PageFlipController();
    _controller = V2ReaderController(
      newsLanguageCode: () => context.read<LanguageProvider>().newsLanguageCode,
      appliedRegion: () => context.read<RegionProvider>().appliedRegion,
    );
    _controller.addListener(_onControllerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onControllerTick() {
    final status = _controller.state.status;
    if (_lastStatus == V2ReaderStatus.loading &&
        (status == V2ReaderStatus.ready || status == V2ReaderStatus.empty)) {
      _feedEpoch++;
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
    await _controller.loadInitial();
    _onArticleVisible();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerTick);
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

  void _goTo(int index) {
    if (_controller.setIndex(index)) {
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
      listenable: _controller,
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
                  onRegionChanged: () => _controller.refresh(),
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
    switch (state.status) {
      case V2ReaderStatus.idle:
      case V2ReaderStatus.loading:
        return const _LoadingState();
      case V2ReaderStatus.error:
        return _ErrorState(
          message: LocalizationHelper.v2ForYouLoadError(context),
          onRetry: _controller.refresh,
        );
      case V2ReaderStatus.empty:
        return _EmptyState(
          message: LocalizationHelper.v2ForYouEmpty(context),
          onRetry: _controller.refresh,
        );
      case V2ReaderStatus.ready:
        final current = state.current;
        return Stack(
          fit: StackFit.expand,
          children: [
            V2PageTurn(
              key: ValueKey('v2_turn_$_feedEpoch'),
              controller: _pageFlipController,
              itemCount: state.articles.length,
              index: state.index,
              canGoNext: state.index < state.articles.length - 1,
              canGoPrevious: state.index > 0,
              onIndexChanged: _goTo,
              itemBuilder: (context, i) {
                final article = state.articles[i];
                return V2ArticlePage(
                  article: article,
                  cutsLabel: cutsLabel,
                  index: i,
                  total: state.total,
                  bookmarked: bookmarks.isBookmarked(article),
                  onBookmark: () => _toggleBookmark(article),
                  onShare: () => _share(article),
                  onViewFullArticle: () => _openFullArticle(article),
                  onPrevious: _flipPrevious,
                  onNext: _flipNext,
                  canPrevious: i > 0,
                  canNext: i < state.articles.length - 1 || state.hasMore,
                  // Hosted in this Stack overlay — outside TurnablePage corners.
                  showHeroActions: false,
                );
              },
            ),
            // Top-right of the reading stage (over hero), outside TurnablePage
            // so taps never compete with the page-curl corner trigger.
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
