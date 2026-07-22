// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/for_you_feed_layout.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/utils/voice_features.dart';
import '../../../core/widgets/audio_mini_player.dart';
import '../../../core/widgets/for_you_featured_mosaic.dart';
import '../../../core/widgets/for_you_feed_shimmer.dart';
import '../../../core/widgets/for_you_spotlight_card.dart';
import '../../../core/widgets/inline_feed_ad.dart';
import '../../../data/services/ad_service.dart';
import '../../../core/widgets/news_share_bottom_sheet.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/remote_config_model.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/for_you_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../news_detail/news_detail_screen.dart';

/// Personalized For You — repeating mosaic + spotlight blocks while scrolling.
class ForYouTab extends StatefulWidget {
  const ForYouTab({super.key});

  @override
  State<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends State<ForYouTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ForYouProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.85) {
      return;
    }
    context.read<ForYouProvider>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Consumer2<ForYouProvider, RemoteConfigProvider>(
      builder: (context, forYouProvider, configProvider, child) {
        final config = configProvider.config;
        final voiceEnabled =
            config.enableVoiceFeatures && VoiceFeatures.isEnabled;

        return SafeArea(
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                _buildBody(
                  context,
                  forYouProvider,
                  config,
                  theme,
                  voiceEnabled,
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AudioMiniPlayer(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ForYouProvider forYouProvider,
    RemoteConfigModel config,
    ThemeData theme,
    bool voiceEnabled,
  ) {
    if (forYouProvider.requiresSignIn) {
      return _buildMessageState(
        theme,
        icon: Icons.person_outline,
        title: LocalizationHelper.forYou(context),
        message: LocalizationHelper.signInToYourAccount(context),
      );
    }

    if (forYouProvider.isLoading && !forYouProvider.hasArticles) {
      return const ForYouFeedShimmer();
    }

    if (forYouProvider.error != null && !forYouProvider.hasArticles) {
      return _buildMessageState(
        theme,
        icon: Icons.error_outline,
        title: LocalizationHelper.forYou(context),
        message: forYouProvider.error!,
        action: TextButton(
          onPressed: () => forYouProvider.refresh(),
          child: Text(LocalizationHelper.retry(context)),
        ),
      );
    }

    if (!forYouProvider.hasArticles) {
      return RefreshIndicator(
        onRefresh: () => forYouProvider.refresh(),
        color: config.primaryColorValue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            _buildMessageState(
              theme,
              icon: Icons.auto_awesome_outlined,
              title: LocalizationHelper.forYou(context),
              message: LocalizationHelper.noNewsAvailable(context),
            ),
          ],
        ),
      );
    }

    final all = forYouProvider.articles;
    final blocks = ForYouFeedLayout.partition(all);

    return RefreshIndicator(
      onRefresh: () => forYouProvider.refresh(),
      color: config.primaryColorValue,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _buildFeedHeader(context, config, theme, all.length),
          for (final block in blocks)
            ..._buildBlockWidgets(
              context,
              block: block,
              all: all,
              config: config,
              voiceEnabled: voiceEnabled,
            ),
          if (forYouProvider.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  List<Widget> _buildBlockWidgets(
    BuildContext context, {
    required ForYouFeedBlock block,
    required List<NewsArticle> all,
    required RemoteConfigModel config,
    required bool voiceEnabled,
  }) {
    final widgets = <Widget>[];

    if (block.index > 0) {
      widgets.add(_buildBlockDivider(context, config));
    }

    if (block.showMosaic) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ForYouFeaturedMosaic(
            articles: block.mosaic,
            primaryColor: config.primaryColorValue,
            showListenOverlay: voiceEnabled,
            onArticleTap: (article, _) {
              final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
              _openDetail(
                context,
                article,
                initialIndex: feedIndex >= 0 ? feedIndex : null,
              );
            },
            onListenTap: voiceEnabled
                ? (article, _) {
                    final index = ForYouFeedLayout.feedIndexOf(all, article);
                    _onListenTapped(
                      context,
                      article,
                      index >= 0 ? index : 0,
                    );
                  }
                : null,
          ),
        ),
      );
    } else if (block.mosaic.length == 1) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ForYouFeaturedMosaic(
            articles: block.mosaic,
            primaryColor: config.primaryColorValue,
            showListenOverlay: voiceEnabled,
            onArticleTap: (article, _) {
              final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
              _openDetail(
                context,
                article,
                initialIndex: feedIndex >= 0 ? feedIndex : null,
              );
            },
            onListenTap: voiceEnabled
                ? (article, _) {
                    final index = ForYouFeedLayout.feedIndexOf(all, article);
                    _onListenTapped(context, article, index >= 0 ? index : 0);
                  }
                : null,
          ),
        ),
      );
    }

    if (block.spotlight.isNotEmpty) {
      if (block.showMosaic || block.mosaic.length == 1) {
        widgets.add(
          _buildSectionTitle(
            context,
            config,
            LocalizationHelper.moreStoriesForYou(context),
          ),
        );
      }
      widgets.add(
        _buildSpotlightGrid(
          context,
          articles: block.spotlight,
          all: all,
          config: config,
          voiceEnabled: voiceEnabled,
          blockIndex: block.index,
        ),
      );
    }

    final adPolicy = AdService().policy;
    if (adPolicy.enabled && adPolicy.forYouBlockAdsEnabled) {
      widgets.add(
        InlineFeedAd(
          key: ValueKey('feed_ad_foryou_${block.index}'),
          slotIndex: block.index,
        ),
      );
    }

    return widgets;
  }

  Widget _buildSpotlightGrid(
    BuildContext context, {
    required List<NewsArticle> articles,
    required List<NewsArticle> all,
    required RemoteConfigModel config,
    required bool voiceEnabled,
    required int blockIndex,
  }) {
    return Padding(
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
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
          return ForYouSpotlightCard(
            key: ValueKey(
              'for_you_spot_${blockIndex}_${index}_${ForYouFeedLayout.articleKey(article)}',
            ),
            article: article,
            primaryColor: config.primaryColorValue,
            showListenButton: voiceEnabled,
            onTap: () {
              final feedIndex = ForYouFeedLayout.feedIndexOf(all, article);
              _openDetail(
                context,
                article,
                initialIndex: feedIndex >= 0 ? feedIndex : index,
              );
            },
            onListenTap: voiceEnabled
                ? () => _onListenTapped(
                      context,
                      article,
                      feedIndex >= 0 ? feedIndex : index,
                    )
                : null,
            onSaveTap: () => _onSaveTapped(context, article),
            onShareTap: () => showNewsShareBottomSheet(context, article),
          );
        },
      ),
    );
  }

  Widget _buildBlockDivider(BuildContext context, RemoteConfigModel config) {
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

  Widget _buildFeedHeader(
    BuildContext context,
    RemoteConfigModel config,
    ThemeData theme,
    int count,
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
            LocalizationHelper.pickedForYouSubtitle(context),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.secondary,
              height: 1.35,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            Text(
              LocalizationHelper.storiesCount(context, count),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.secondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    RemoteConfigModel config,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: config.primaryColorValue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onListenTapped(
    BuildContext context,
    NewsArticle article,
    int index,
  ) async {
    try {
      final playlist = context.read<ForYouProvider>().articles;
      final audioProvider = context.read<AudioPlayerProvider>();

      if (playlist.length > 1) {
        await audioProvider.setPlaylistAndPlay(
          playlist,
          index.clamp(0, playlist.length - 1),
          playTitle: true,
          category: 'for_you',
        );
      } else {
        await audioProvider.playArticleFromUrl(
          article,
          playTitle: true,
          category: 'for_you',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              LocalizationHelper.errorPlayingAudio(context, e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onSaveTapped(BuildContext context, NewsArticle article) async {
    try {
      final bookmarkProvider = context.read<BookmarkProvider>();
      final newStatus = await bookmarkProvider.toggleBookmark(article);
      context.read<NewsProvider>().updateArticleBookmarkStatus(
            article,
            newStatus,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _openDetail(
    BuildContext context,
    NewsArticle article, {
    int? initialIndex,
  }) {
    final articles = context.read<ForYouProvider>().articles;
    NewsDetailScreen.open(
      context,
      article: article,
      articles: articles,
      initialIndex: initialIndex,
    );
  }
}
