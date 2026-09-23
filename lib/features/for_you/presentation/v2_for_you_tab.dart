import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../app/routing/v2_routes.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/for_you_feed_layout.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/utils/voice_features.dart';
import '../../../core/widgets/for_you_featured_mosaic.dart';
import '../../../core/widgets/for_you_feed_shimmer.dart';
import '../../../core/widgets/for_you_spotlight_card.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/region_model.dart';
import '../../../data/models/remote_config_model.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../news/domain/news_summary.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../data/for_you_repository.dart';
import 'for_you_controller.dart';

/// V2 For You tab — mosaic + spotlight presentation (V1 visual quality)
/// backed entirely by the V2 For You API / [ForYouController].
class V2ForYouTab extends StatefulWidget {
  const V2ForYouTab({super.key});

  @override
  State<V2ForYouTab> createState() => _V2ForYouTabState();
}

class _V2ForYouTabState extends State<V2ForYouTab>
    with AutomaticKeepAliveClientMixin {
  late final ForYouController _controller;
  final ScrollController _scroll = ScrollController();
  final Set<String> _impressedIds = <String>{};
  bool _sectionImpressed = false;
  bool _bootstrapped = false;
  RegionProvider? _region;
  String? _lastRegionKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = ForYouController(
      repository: ForYouRepository(),
      newsLanguageCode: () => context.read<LanguageProvider>().newsLanguageCode,
      appliedRegion: () => context.read<RegionProvider>().appliedRegion,
    );
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootstrapped || !mounted) return;
      _bootstrapped = true;
      final region = context.read<RegionProvider>();
      if (!region.isInitialized) {
        await region.initialize();
      }
      if (!mounted) return;
      _region = region;
      _lastRegionKey = _regionKey(region.appliedRegion);
      region.addListener(_onRegionChanged);
      await _controller.refresh();
    });
  }

  @override
  void dispose() {
    _region?.removeListener(_onRegionChanged);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _regionKey(SavedRegion region) => region.toQueryParams().toString();

  void _onRegionChanged() {
    if (!mounted || _region == null) return;
    final key = _regionKey(_region!.appliedRegion);
    if (key == _lastRegionKey) return;
    _lastRegionKey = key;
    _impressedIds.clear();
    _sectionImpressed = false;
    _controller.refresh();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _controller.loadMore();
    }
  }

  Future<void> _open(NewsArticle article, int index) async {
    await AnalyticsService.instance.newsOpen(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
    await AnalyticsService.instance.forYouImpression(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
    if (!mounted) return;
    await V2Routes.openArticle(
      context,
      article: article,
      articles: _controller.state.articles,
      initialIndex: index,
    );
  }

  Future<void> _bookmark(NewsArticle article) async {
    final bookmarks = context.read<BookmarkProvider>();
    await bookmarks.toggleBookmarkV2(article);
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

  void _emitImpressions(List<NewsArticle> articles) {
    if (!_sectionImpressed && articles.isNotEmpty) {
      _sectionImpressed = true;
      AnalyticsService.instance.forYouImpression(v2Only: true);
    }
    for (final a in articles.take(8)) {
      final id = a.analyticsNewsId;
      if (_impressedIds.contains(id)) continue;
      _impressedIds.add(id);
      AnalyticsService.instance.forYouImpression(newsId: id, v2Only: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final config = context.watch<RemoteConfigProvider>().config;
    final voiceEnabled =
        config.enableVoiceFeatures && VoiceFeatures.isEnabled;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (state.status == ForYouStatus.ready && state.articles.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _emitImpressions(state.articles);
          });
        }

        return SafeArea(
          child: RefreshIndicator(
            color: config.primaryColorValue,
            onRefresh: () async {
              _impressedIds.clear();
              _sectionImpressed = false;
              await _controller.refresh();
            },
            child: _buildBody(theme, config, state, voiceEnabled),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    ThemeData theme,
    RemoteConfigModel config,
    ForYouState state,
    bool voiceEnabled,
  ) {
    if (state.status == ForYouStatus.loading && state.articles.isEmpty) {
      return const ForYouFeedShimmer();
    }

    if (state.status == ForYouStatus.error && state.articles.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          _message(
            theme,
            icon: Icons.cloud_off_outlined,
            title: LocalizationHelper.forYou(context),
            message: LocalizationHelper.v2ForYouLoadError(context),
            action: FilledButton(
              onPressed: _controller.refresh,
              child: Text(LocalizationHelper.retry(context)),
            ),
          ),
        ],
      );
    }

    if (state.articles.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          _message(
            theme,
            icon: Icons.auto_awesome_outlined,
            title: LocalizationHelper.forYou(context),
            message: LocalizationHelper.v2ForYouEmpty(context),
          ),
        ],
      );
    }

    final all = state.articles;
    final blocks = ForYouFeedLayout.partition(all);

    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _feedHeader(theme, config, all.length, state.isColdStart),
        for (final block in blocks)
          ..._blockWidgets(
            block: block,
            all: all,
            config: config,
            voiceEnabled: voiceEnabled,
          ),
        if (state.status == ForYouStatus.loadingMore)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 96),
      ],
    );
  }

  Widget _feedHeader(
    ThemeData theme,
    RemoteConfigModel config,
    int count,
    bool coldStart,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: config.primaryColorValue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                LocalizationHelper.forYou(context),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: config.primaryColorValue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            coldStart
                ? LocalizationHelper.v2ForYouFallbackCopy(context)
                : LocalizationHelper.pickedForYouSubtitle(context),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            Text(
              LocalizationHelper.storiesCount(context, count),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _blockWidgets({
    required ForYouFeedBlock block,
    required List<NewsArticle> all,
    required RemoteConfigModel config,
    required bool voiceEnabled,
  }) {
    final widgets = <Widget>[];

    if (block.index > 0) {
      widgets.add(_blockDivider(config));
    }

    if (block.showMosaic || block.mosaic.length == 1) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ForYouFeaturedMosaic(
            articles: block.mosaic,
            primaryColor: config.primaryColorValue,
            showListenOverlay: voiceEnabled,
            onArticleTap: (article, _) {
              final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
              _open(article, feedIndex >= 0 ? feedIndex : 0);
            },
          ),
        ),
      );
    }

    if (block.spotlight.isNotEmpty) {
      if (block.showMosaic || block.mosaic.length == 1) {
        widgets.add(_sectionTitle(config));
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: block.spotlight.length,
            itemBuilder: (context, index) {
              final article = block.spotlight[index];
              final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
              return ForYouSpotlightCard(
                key: ValueKey(
                  'v2_fy_spot_${block.index}_${index}_${ForYouFeedLayout.articleKey(article)}',
                ),
                article: article,
                primaryColor: config.primaryColorValue,
                showListenButton: false,
                onTap: () => _open(article, feedIndex >= 0 ? feedIndex : index),
                onSaveTap: () => _bookmark(article),
                onShareTap: () => _share(article),
              );
            },
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _blockDivider(RemoteConfigModel config) {
    final label = LocalizationHelper.moreStoriesForYou(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: config.primaryColorValue.withValues(alpha: 0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: config.primaryColorValue,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: config.primaryColorValue,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Divider(
              color: config.primaryColorValue.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(RemoteConfigModel config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Text(
        LocalizationHelper.moreStoriesForYou(context),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: config.primaryColorValue,
        ),
      ),
    );
  }

  Widget _message(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }
}
