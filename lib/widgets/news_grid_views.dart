// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:provider/provider.dart';

import '../data/models/news_article.dart';
import '../data/models/remote_config_model.dart';
import '../providers/remote_config_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_player_provider.dart';
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
            ? showBannerView(config, newsDetails, context, theme)
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
        style: GoogleFonts.inter(
          color: config.primaryColorValue,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      );
    } else if (type.toLowerCase() == 'postedtime') {
      return Text(
        _getTimeAgo(newsDetails),
        style: GoogleFonts.inter(color: config.primaryColorValue),
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
              color:
                  isBookmarked
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
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        // Check if this specific article is currently playing or paused
        final currentArticle = audioProvider.currentArticle;
        final isThisArticlePlaying = currentArticle != null &&
            _isSameArticle(newsDetails, currentArticle);
        
        final isPlaying = isThisArticlePlaying && audioProvider.isPlaying;
        final isPaused = isThisArticlePlaying && audioProvider.isPaused;
        final isLoading = isThisArticlePlaying && audioProvider.isLoading;
        
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
              color: config.primaryColorValue,
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
                  showImage(config.listenIcon, BoxFit.contain, height: 15, width: 15),
                giveWidth(12),
                Flexible(
                  child: Text(
                    isPlaying 
                        ? 'Playing...' 
                        : isPaused 
                            ? 'Paused' 
                            : LocalizationHelper.listen(context),
                    style: GoogleFonts.playfair(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
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
    if (a.articleId != null && b.articleId != null && a.articleId!.isNotEmpty && b.articleId!.isNotEmpty) {
      return a.articleId == b.articleId;
    }
    return a.title == b.title;
  }

  showRoundedListenButton(RemoteConfigModel config, BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        final currentArticle = audioProvider.currentArticle;
        final isThisArticlePlaying = currentArticle != null &&
            _isSameArticle(newsDetails, currentArticle);
        
        final isPlaying = isThisArticlePlaying && audioProvider.isPlaying;
        final isPaused = isThisArticlePlaying && audioProvider.isPaused;
        final isLoading = isThisArticlePlaying && audioProvider.isLoading;
        
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
                color: config.primaryColorValue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : isPlaying
                        ? const Icon(Icons.pause, color: Colors.white, size: 20)
                        : isPaused
                            ? const Icon(Icons.play_arrow, color: Colors.white, size: 20)
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

  showListView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => onNewsTapped(),
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            showImage(
              newsDetails.imageUrl ?? newsDetails.sourceIcon ?? '',
              BoxFit.contain,
              height: 200,
              width: MediaQuery.of(context).size.width / 2.5,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
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
                      style: GoogleFonts.inriaSerif(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
                  giveHeight(3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      showListenButton(config, context),
                      showCommonWidget(
                        config,
                        'save',
                        newsDetails,
                        theme,
                        context,
                      ),
                      showShareButton(theme),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  showCardView(
    RemoteConfigModel config,
    NewsArticle newsDetails,
    BuildContext context,
    ThemeData theme,
  ) {
    return GestureDetector(
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
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE31E24),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      newsDetails.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [showListenButton(config, context)],
                    ),
                  ],
                ),
              ),

              // 🔖 Top-right bookmark
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
    return GestureDetector(
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
                    showRoundedListenButton(config, context),
                    const SizedBox(height: 14),
                    Text(
                      newsDetails.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
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
