import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/language_provider.dart';
import '../../news/data/related_news_service.dart';
import '../../news/domain/news_summary.dart';
import '../../news/presentation/widgets/newson_cut_card.dart';
import '../../publishers/presentation/widgets/publisher_attribution.dart';
import '../../audio/presentation/v2_audio_scope.dart';
import '../../audio/presentation/widgets/audio_button.dart';
import '../../audio/presentation/widgets/audio_player_bar.dart';
import '../../../core/config/v2_feature_flags.dart';
import '../../../providers/remote_config_provider.dart';
import '../domain/article_detail_analytics.dart';
import 'full_article_screen.dart';
import 'widgets/page_turn_transition.dart';

/// V2 article experience: Cut → Full Article → Related.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.articles,
    this.initialIndex = 0,
    this.enablePageTurn = false,
    this.enableRelated = false,
    this.enableFullArticle = true,
    this.cutsLabel = 'NewsOn Cuts',
  });

  final NewsArticle article;
  final List<NewsArticle>? articles;
  final int initialIndex;
  final bool enablePageTurn;
  final bool enableRelated;
  final bool enableFullArticle;
  final String cutsLabel;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late PageController _pageController;
  late List<NewsArticle> _pages;
  late int _index;
  bool _summaryViewed = false;

  @override
  void initState() {
    super.initState();
    _pages = (widget.articles != null && widget.articles!.isNotEmpty)
        ? List<NewsArticle>.from(widget.articles!)
        : [widget.article];
    _index = widget.initialIndex.clamp(0, _pages.length - 1);
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onArticleVisible(_pages[_index]);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onArticleVisible(NewsArticle article) {
    try {
      AnalyticsService.instance.newsOpen(newsId: article.analyticsNewsId);
    } catch (e) {
      debugPrint('⚠️ news_open analytics failed: $e');
    }
    try {
      InteractionService().trackOpen(article);
    } catch (e) {
      debugPrint('⚠️ interaction open failed: $e');
    }
    _summaryViewed = false;
    _maybeTrackSummary(article);
  }

  void _maybeTrackSummary(NewsArticle article) {
    if (!ArticleDetailAnalytics.shouldTrackSummaryView(
      article: article,
      alreadyTracked: _summaryViewed,
    )) {
      return;
    }
    _summaryViewed = true;
    AnalyticsService.instance.summaryView(newsId: article.analyticsNewsId);
  }

  Future<void> _openFullArticle(NewsArticle article) async {
    final url = article.canonicalArticleUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(LocalizationHelper.v2SummaryUnavailable(context))),
      );
      return;
    }
    await AnalyticsService.instance.fullArticleClick(
      newsId: article.analyticsNewsId,
      url: url,
    );
    if (!mounted) return;
    if (!widget.enableFullArticle) {
      // Flag off: still allow external browser as safe CTA.
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullArticleScreen(
          url: url,
          title: article.title,
          publisherName: article.publisherDisplayName,
        ),
      ),
    );
  }

  Future<void> _toggleBookmark(NewsArticle article) async {
    await context.read<BookmarkProvider>().toggleBookmark(article);
    await InteractionService().trackBookmark(article);
    await AnalyticsService.instance.log(
      AnalyticsEvents.bookmark,
      params: {'newsId': article.analyticsNewsId},
      dedupeKey: 'bookmark::${article.analyticsNewsId}',
      dedupeFor: const Duration(seconds: 1),
    );
  }

  Future<void> _share(NewsArticle article) async {
    await NewsShareService.shareArticle(article);
    await InteractionService().trackShare(article);
    await AnalyticsService.instance.log(
      AnalyticsEvents.share,
      params: {'newsId': article.analyticsNewsId},
      dedupeKey: 'share::${article.analyticsNewsId}',
      dedupeFor: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final usePageView = widget.enablePageTurn && _pages.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cutsLabel),
      ),
      body: V2AudioScope(
        controller: V2AudioControllerHolder.obtain(),
        child: Column(
          children: [
            Expanded(
              child: usePageView
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      physics: reduceMotion
                          ? const ClampingScrollPhysics()
                          : const BouncingScrollPhysics(),
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        _onArticleVisible(_pages[i]);
                      },
                      itemBuilder: (context, i) => _ArticleDetailBody(
                        article: _pages[i],
                        cutsLabel: widget.cutsLabel,
                        enableRelated: widget.enableRelated,
                        enableFullArticle: widget.enableFullArticle,
                        onFullArticle: () => _openFullArticle(_pages[i]),
                        onBookmark: () => _toggleBookmark(_pages[i]),
                        onShare: () => _share(_pages[i]),
                        onRelatedTap: (related) {
                          Navigator.of(context).push(
                            PageTurnPageRoute<void>(
                              enabled: widget.enablePageTurn,
                              builder: (_) => ArticleDetailScreen(
                                article: related,
                                enablePageTurn: false,
                                enableRelated: widget.enableRelated,
                                enableFullArticle: widget.enableFullArticle,
                                cutsLabel: widget.cutsLabel,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : _ArticleDetailBody(
                      article: _pages[_index],
                      cutsLabel: widget.cutsLabel,
                      enableRelated: widget.enableRelated,
                      enableFullArticle: widget.enableFullArticle,
                      onFullArticle: () => _openFullArticle(_pages[_index]),
                      onBookmark: () => _toggleBookmark(_pages[_index]),
                      onShare: () => _share(_pages[_index]),
                      onRelatedTap: (related) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArticleDetailScreen(
                              article: related,
                              enableRelated: widget.enableRelated,
                              enableFullArticle: widget.enableFullArticle,
                              cutsLabel: widget.cutsLabel,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (V2FeatureFlags.audio(
              context.watch<RemoteConfigProvider>().config,
            ))
              V2AudioPlayerBar(
                controller: V2AudioControllerHolder.obtain(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleDetailBody extends StatefulWidget {
  const _ArticleDetailBody({
    required this.article,
    required this.cutsLabel,
    required this.enableRelated,
    required this.enableFullArticle,
    required this.onFullArticle,
    required this.onBookmark,
    required this.onShare,
    required this.onRelatedTap,
  });

  final NewsArticle article;
  final String cutsLabel;
  final bool enableRelated;
  final bool enableFullArticle;
  final VoidCallback onFullArticle;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final ValueChanged<NewsArticle> onRelatedTap;

  @override
  State<_ArticleDetailBody> createState() => _ArticleDetailBodyState();
}

class _ArticleDetailBodyState extends State<_ArticleDetailBody> {
  RelatedNewsService? _relatedNewsService;
  List<NewsArticle> _related = const [];
  bool _relatedLoading = false;
  bool _relatedFailed = false;

  RelatedNewsService get _relatedApi =>
      _relatedNewsService ??= RelatedNewsService();

  @override
  void initState() {
    super.initState();
    if (widget.enableRelated) {
      _loadRelated();
    }
  }

  @override
  void didUpdateWidget(covariant _ArticleDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.analyticsNewsId != widget.article.analyticsNewsId &&
        widget.enableRelated) {
      _loadRelated();
    }
  }

  Future<void> _loadRelated() async {
    setState(() {
      _relatedLoading = true;
      _relatedFailed = false;
    });
    try {
      final lang = context.read<LanguageProvider>().getApiLanguageCode();
      final list = await _relatedApi.fetchRelated(
        article: widget.article,
        language: lang,
      );
      if (!mounted) return;
      setState(() {
        _related = list;
        _relatedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _relatedFailed = true;
        _relatedLoading = false;
        _related = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final theme = Theme.of(context);
    final status = article.resolvedSummaryStatus;
    final cut = article.newsOnCutText;
    final categories = (article.category ?? const <String>[])
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
    final relative = () {
      final dt = DateFormatter.parseApiDate(article.pubDate);
      return dt == null ? '' : DateFormatter.getRelativeTime(dt);
    }();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1200,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categories.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categories
                            .take(3)
                            .map(
                              (c) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: PublisherAttribution(
                            article: article,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (relative.isNotEmpty)
                          Text(
                            relative,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.cutsLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LocalizationHelper.v2NewsOnCutsSubtitle(context),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CutBlock(status: status, cut: cut),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: V2AudioButton(article: article),
                    ),
                    const SizedBox(height: 12),
                    if (widget.enableFullArticle) ...[
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          button: true,
                          label: LocalizationHelper.v2ViewFullArticle(context),
                          child: ElevatedButton.icon(
                            onPressed: widget.onFullArticle,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              LocalizationHelper.v2ViewFullArticle(context),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Selector<BookmarkProvider, bool>(
                          selector: (_, p) => p.isBookmarked(article),
                          builder: (context, bookmarked, _) {
                            return IconButton(
                              tooltip: LocalizationHelper.v2Bookmark(context),
                              onPressed: widget.onBookmark,
                              icon: Icon(
                                bookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: LocalizationHelper.v2Share(context),
                          onPressed: widget.onShare,
                          icon: const Icon(Icons.share_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.enableRelated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationHelper.v2RelatedNews(context),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_relatedLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_relatedFailed || _related.isEmpty)
                    Text(
                      LocalizationHelper.v2NoRelatedNews(context),
                      style: TextStyle(color: theme.hintColor),
                    )
                  else
                    ..._related.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NewsOnCutCard(
                          article: r,
                          cutsLabel: widget.cutsLabel,
                          onTap: () => widget.onRelatedTap(r),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CutBlock extends StatelessWidget {
  const _CutBlock({
    required this.status,
    required this.cut,
  });

  final NewsSummaryStatus status;
  final String? cut;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case NewsSummaryStatus.available:
        return Text(
          cut!,
          style: GoogleFonts.inter(fontSize: 16, height: 1.5),
        );
      case NewsSummaryStatus.pending:
        return Text(
          LocalizationHelper.v2SummaryComingSoon(context),
          style: GoogleFonts.inter(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).hintColor,
          ),
        );
      case NewsSummaryStatus.failed:
      case NewsSummaryStatus.unavailable:
        // Never show description / placeholders as a NewsOn Cut.
        return Text(
          LocalizationHelper.v2SummaryUnavailable(context),
          style: TextStyle(color: Theme.of(context).hintColor),
        );
    }
  }
}
