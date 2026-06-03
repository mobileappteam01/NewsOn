// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/core/services/font_manager.dart';
import 'package:provider/provider.dart';

import '../core/widgets/animated_pressable.dart';
import '../data/models/news_article.dart';
import '../data/models/remote_config_model.dart';
import '../providers/remote_config_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/completed_news_provider.dart';
import '../core/utils/date_formatter.dart';

class NewsGridView extends StatelessWidget {
  final String type;
  final NewsArticle newsDetails;
  Function onListenTapped;
  Function onNewsTapped;
  Function onSaveTapped;
  Function onShareTapped;
  NewsGridView({
    super.key,
    required this.type,
    required this.newsDetails,
    required this.onListenTapped,
    required this.onNewsTapped,
    required this.onSaveTapped,
    required this.onShareTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;

        // final isDark = theme.brightness == Brightness.dark;

        return type.toLowerCase() == 'listview'
            ? showListView(config, newsDetails, context, theme)
            : type.toLowerCase() == 'cardview'
                ? showCardView(config, newsDetails, context, theme)
                : type.toLowerCase() == 'thumbnail'
                    ? showThumbNailView(config, newsDetails, context, theme)
                    : type.toLowerCase() == 'detailedview'
                        ? showDetailedView(config, newsDetails, context, theme)
                        : type.toLowerCase() == 'bannerview'
                            ? showBannerView(
                                config, newsDetails, context, theme)
                            : showListView(config, newsDetails, context, theme);
      },
    );
  }

  /// Get relative time string from article's pubDate
  static String _getTimeAgo(NewsArticle article) {
    if (article.pubDate == null || article.pubDate!.isEmpty) {
      return 'Just now';
    }

    // Parse the pubDate - format is "2025-11-24 00:00:00"
    final dateTime = DateFormatter.parseApiDate(article.pubDate);

    if (dateTime == null) {
      return 'Just now';
    }

    return DateFormatter.getRelativeTime(dateTime);
  }

  showCommonWidget(
    RemoteConfigModel config,
    String type,
    NewsArticle newsDetails,
    ThemeData theme,
    BuildContext context,
  ) {
    if (type.toLowerCase() == 'category') {
      return Text(
        newsDetails.category!.isNotEmpty ? newsDetails.category![0] : "",
        style: FontManager.newsCategory.copyWith(
          color: config.primaryColorValue,
          fontSize: 11,
        ),
      );
    } else if (type.toLowerCase() == 'postedtime') {
      return Text(
        _getTimeAgo(newsDetails),
        style:
            FontManager.newsTimestamp.copyWith(color: config.primaryColorValue),
      );
    } else if (type.toLowerCase() == 'save') {
      // Bookmark icon - synced with BookmarkProvider
      return Consumer<BookmarkProvider>(
        builder: (context, bookmarkProvider, child) {
          final isBookmarked = bookmarkProvider.isBookmarked(newsDetails);
          final isDark = theme.brightness == Brightness.dark;

          return GestureDetector(
            onTap: () => onSaveTapped(),
            child: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked
                  ? (isDark
                      ? theme.primaryColor
                      : const Color(0xFFE31E24)) // Red when bookmarked
                  : (isDark
                      ? Colors.grey[400]
                      : Colors.grey[600]), // Grey when not bookmarked
              size: 24,
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  showListenButton(RemoteConfigModel config, BuildContext context) {
    if (!config.enableVoiceFeatures) {
      return const SizedBox.shrink();
    }

    final completedProvider = Provider.of<CompletedNewsProvider>(context);
    final newsId = newsDetails.articleId ?? newsDetails.title;
    final isNewsCompleted = completedProvider.isCompleted(newsId);

    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        final currentArticle = audioProvider.currentArticle;
        final isThisArticlePlaying = currentArticle != null &&
            _isSameArticle(newsDetails, currentArticle);

        final isPlaying = isThisArticlePlaying && audioProvider.isPlaying;
        final isPaused = isThisArticlePlaying && audioProvider.isPaused;
        final isLoading = isThisArticlePlaying && audioProvider.isLoading;

        final buttonColor = isNewsCompleted
            ? const Color(0xFF2E7D32)
            : config.primaryColorValue;

        return GestureDetector(
          onTap: () {
            if (isPlaying) {
              audioProvider.pause();
            } else if (isPaused) {
              audioProvider.resume();
            } else {
              onListenTapped();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: buttonColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (isPlaying)
                  const Icon(Icons.pause, color: Colors.white, size: 15)
                else if (isPaused)
                  const Icon(Icons.play_arrow, color: Colors.white, size: 15)
                else
                  showImage(
                    config.listenIcon,
                    BoxFit.contain,
                    height: 15,
                    width: 15,
                  ),
                giveWidth(12),
                Flexible(
                  child: Text(
                    isPlaying
                        ? 'Playing...'
                        : isPaused
                            ? 'Paused'
                            : LocalizationHelper.listen(context),
                    style: FontManager.button.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper function to check if two articles are the same
  bool _isSameArticle(NewsArticle a, NewsArticle b) {
    final keyA = a.newsId ?? a.articleId ?? a.title;
    final keyB = b.newsId ?? b.articleId ?? b.title;
    return keyA == keyB;
  }

  showRoundedListenButton(RemoteConfigModel config, BuildContext context) {
    if (!config.enableVoiceFeatures) {
      return const SizedBox.shrink();
    }

    final completedProvider = Provider.of<CompletedNewsProvider>(context);
    final newsId = newsDetails.articleId ?? newsDetails.title;
    final isNewsCompleted = completedProvider.isCompleted(newsId);

    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        final currentArticle = audioProvider.currentArticle;
        final isThisArticlePlaying = currentArticle != null &&
            _isSameArticle(newsDetails, currentArticle);

        final isPlaying = isThisArticlePlaying && audioProvider.isPlaying;
        final isPaused = isThisArticlePlaying && audioProvider.isPaused;
        final isLoading = isThisArticlePlaying && audioProvider.isLoading;

        final buttonColor = isNewsCompleted
            ? const Color(0xFF2E7D32)
            : config.primaryColorValue;

        return GestureDetector(
          onTap: () {
            if (isPlaying) {
              audioProvider.pause();
            } else if (isPaused) {
              audioProvider.resume();
            } else {
              onListenTapped();
            }
          },
          child: Center(
            child: Container(
              height: 50,
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : isPlaying
                        ? const Icon(Icons.pause, color: Colors.white, size: 20)
                        : isPaused
                            ? const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              )
                            : showImage(
                                config.listenIcon,
                                BoxFit.contain,
                                height: 15,
                                width: 15,
                              ),
              ),
            ),
          ),
        );
      },
    );
  }

  showShareButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => onShareTapped(),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.1416),
        child: Icon(
          Icons.reply_outlined,
          size: 24,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }

  /// Bottom action row for list items — full listen + icons, or a balanced save/share bar.
  Widget _buildListActionRow(
    RemoteConfigModel config,
    BuildContext context,
    ThemeData theme,
  ) {
    if (config.enableVoiceFeatures) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: showListenButton(config, context)),
          const SizedBox(width: 10),
          showCommonWidget(config, 'save', newsDetails, theme, context),
          const SizedBox(width: 8),
          showShareButton(theme),
        ],
      );
    }

    return _buildSaveShareActionBar(config, theme, context);
  }

  /// Segmented save / share bar when voice is off (list + card footers).
  Widget _buildSaveShareActionBar(
    RemoteConfigModel config,
    ThemeData theme,
    BuildContext context, {
    bool onDarkBackground = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = onDarkBackground
        ? Colors.white.withOpacity(0.35)
        : (isDark ? Colors.white24 : Colors.black12);
    final labelColor = onDarkBackground
        ? Colors.white.withOpacity(0.95)
        : theme.colorScheme.onSurface;
    final dividerColor = onDarkBackground
        ? Colors.white.withOpacity(0.25)
        : theme.dividerColor.withOpacity(0.5);
    final fillColor = onDarkBackground
        ? Colors.white.withOpacity(0.12)
        : config.primaryColorValue.withOpacity(isDark ? 0.12 : 0.06);

    Widget actionCell({
      required VoidCallback onTap,
      required Widget icon,
      required String label,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: FontManager.button.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget saveIcon;
    if (onDarkBackground) {
      saveIcon = Consumer<BookmarkProvider>(
        builder: (context, bookmarkProvider, child) {
          final isBookmarked = bookmarkProvider.isBookmarked(newsDetails);
          return Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? const Color(0xFFFFD54F) : Colors.white,
            size: 22,
          );
        },
      );
    } else {
      saveIcon = showCommonWidget(
        config,
        'save',
        newsDetails,
        theme,
        context,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            actionCell(
              onTap: () => onSaveTapped(),
              icon: saveIcon,
              label: LocalizationHelper.bookmark(context),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: dividerColor,
            ),
            actionCell(
              onTap: () => onShareTapped(),
              icon: Icon(
                Icons.ios_share_rounded,
                size: 22,
                color: onDarkBackground
                    ? Colors.white
                    : theme.colorScheme.secondary,
              ),
              label: 'Share',
            ),
          ],
        ),
      ),
    );
  }

  showListView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {
    return Column(
      children: [
        AnimatedPressable(
          onTap: () => onNewsTapped(),
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                showImage(
                  newsDetails.imageUrl ?? newsDetails.sourceIcon ?? '',
                  BoxFit.contain,
                  height: MediaQuery.of(context).size.height / 5.5,
                  width: MediaQuery.of(context).size.width / 2.5,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2.2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      showCommonWidget(
                        config,
                        'category',
                        newsDetails,
                        theme,
                        context,
                      ),
                      giveHeight(3),
                      SizedBox(
                        child: Text(
                          newsDetails.title,
                          style: FontManager.newsSubtitle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      giveHeight(3),
                      showCommonWidget(
                        config,
                        'postedtime',
                        newsDetails,
                        theme,
                        context,
                      ),
                      giveHeight(6),
                      _buildListActionRow(config, context, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          color: Colors.grey.withOpacity(0.3),
          thickness: 1.6,
          endIndent: 5,
          indent: 5,
        ),
      ],
    );
  }

  showCardView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {
    return AnimatedPressable(
      onTap: () => onNewsTapped(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼 Background image
              showImage(newsDetails.sourceIcon!, BoxFit.cover),

              // 🌑 Gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // 🔤 Bottom content
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newsDetails.category!.isNotEmpty
                          ? newsDetails.category![0]
                          : "",
                      style: FontManager.newsCategory.copyWith(
                        color: const Color(0xFFE31E24),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      newsDetails.title,
                      style: FontManager.newsTitle.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (config.enableVoiceFeatures) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [showListenButton(config, context)],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      _buildSaveShareActionBar(
                        config,
                        theme,
                        context,
                        onDarkBackground: true,
                      ),
                    ],
                  ],
                ),
              ),

              // 🔖 Top-right bookmark (listen layout only)
              if (config.enableVoiceFeatures)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(
                      Icons.bookmark_border,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => onSaveTapped(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  showBannerView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {
    return AnimatedPressable(
      onTap: () => onNewsTapped(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼 Background image
              showImage(newsDetails.sourceIcon!, BoxFit.cover),

              // 🌑 Gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // 🔤 Bottom content
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (config.enableVoiceFeatures) ...[
                      showRoundedListenButton(config, context),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      newsDetails.title,
                      style: FontManager.newsTitle.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!config.enableVoiceFeatures) ...[
                      const SizedBox(height: 12),
                      _buildSaveShareActionBar(
                        config,
                        theme,
                        context,
                        onDarkBackground: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  showThumbNailView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {}

  showDetailedView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {}
}
