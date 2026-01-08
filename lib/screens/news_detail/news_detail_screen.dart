// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/news_article.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/audio_loading_overlay.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with WidgetsBindingObserver {
  double _contentTextSize = AppConstants.defaultTextSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTextSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTextSize();
    }
  }

  void _loadTextSize() {
    final savedSize = StorageService.getSetting(
      AppConstants.textSizeKey,
      defaultValue: AppConstants.defaultTextSize,
    );
    if (mounted) {
      setState(() {
        _contentTextSize =
            (savedSize is double) ? savedSize : AppConstants.defaultTextSize;
      });
    }
  }

  /// Get the article content text to display
  String _getArticleContent() {
    // First try to use actual content if available and valid
    if (widget.article.content != null &&
        widget.article.content!.isNotEmpty &&
        widget.article.content != 'ONLY AVAILABLE IN PAID PLANS') {
      return widget.article.content!;
    }
    // Fallback to description
    if (widget.article.description != null &&
        widget.article.description!.isNotEmpty) {
      return widget.article.description!;
    }
    // Final fallback to placeholder text
    return 'White House trade adviser Peter Navarro accused India of helping finance Russia\'s war in Ukraine through continued oil imports, describing the conflict as "Modi\'s war."';
  }

  /// Get relative time string from article's pubDate
  String _getTimeAgo() {
    if (widget.article.pubDate == null || widget.article.pubDate!.isEmpty) {
      return 'Just now';
    }

    // Parse the pubDate - format is "2025-11-24 00:00:00"
    final dateTime = DateFormatter.parseApiDate(widget.article.pubDate);

    if (dateTime == null) {
      return 'Just now';
    }

    return DateFormatter.getRelativeTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<RemoteConfigProvider>(
        builder: (context, configProvider, child) {
          final config = configProvider.config;

          return Stack(
            children: [
              Column(
                children: [
                  /// 🔹 HEADER IMAGE + OVERLAY
                  Stack(
                    children: [
                      // Background image
                      CachedNetworkImage(
                        imageUrl:
                            widget.article.imageUrl ??
                            widget.article.sourceIcon ??
                            '',
                        height: 380,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),

                      // Gradient Overlay
                      Container(
                        height: 380,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),

                      // Top AppBar section
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(25),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              giveWidth(12),
                              showImage(
                                config.appNameLogo,
                                BoxFit.contain,
                                height: 60,
                                width: 80,
                              ),
                              const Spacer(),

                              // Bookmark + Share buttons
                            ],
                          ),
                        ),
                      ),

                      // Title overlay (bottom)
                      Positioned(
                        bottom: 35,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.category?.first ?? "Politics",
                              style: GoogleFonts.inter(
                                color: config.primaryColorValue,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '"${widget.article.title}"',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _getTimeAgo(),
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  /// 🔹 CONTENT AREA
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// AUDIO CONTROL BAR
                            Consumer<AudioPlayerProvider>(
                              builder: (context, audioProvider, child) {
                                final isCurrentArticle =
                                    audioProvider.currentArticle != null &&
                                    (audioProvider.currentArticle!.articleId ??
                                            audioProvider
                                                .currentArticle!
                                                .title) ==
                                        (widget.article.articleId ??
                                            widget.article.title);

                                final isPlaying =
                                    isCurrentArticle && audioProvider.isPlaying;
                                final isLoading =
                                    isCurrentArticle && audioProvider.isLoading;

                                // Calculate progress
                                final duration = audioProvider.duration;
                                final position = audioProvider.position;
                                final progress =
                                    duration.inMilliseconds > 0
                                        ? position.inMilliseconds /
                                            duration.inMilliseconds
                                        : 0.0;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: config.primaryColorValue,
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Audio icon
                                            Icon(
                                              Icons.graphic_eq_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            giveWidth(4),

                                            // Play/Pause button
                                            GestureDetector(
                                              onTap:
                                                  isLoading
                                                      ? null
                                                      : () async {
                                                        if (isCurrentArticle) {
                                                          // Toggle play/pause for current article
                                                          await audioProvider
                                                              .togglePlayPause();
                                                        } else {
                                                          // Play this article (description then content)
                                                          try {
                                                            await audioProvider
                                                                .playArticleFromUrl(
                                                                  widget
                                                                      .article,
                                                                  playTitle: false,
                                                                );
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Failed to play audio: ${e.toString()}',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                child:
                                                    isLoading
                                                        ? SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                        : Icon(
                                                          isPlaying
                                                              ? Icons.pause
                                                              : Icons
                                                                  .play_arrow,
                                                          color: Colors.white,
                                                          size: 22,
                                                        ),
                                              ),
                                            ),

                                            giveWidth(4),

                                            // Progress slider
                                            Expanded(
                                              child: SliderTheme(
                                                data: SliderTheme.of(
                                                  context,
                                                ).copyWith(
                                                  trackHeight: 2,
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                        enabledThumbRadius: 4,
                                                      ),
                                                  overlayShape:
                                                      const RoundSliderOverlayShape(
                                                        overlayRadius: 8,
                                                      ),
                                                ),
                                                child: Slider(
                                                  value: progress.clamp(
                                                    0.0,
                                                    1.0,
                                                  ),
                                                  onChanged:
                                                      duration.inMilliseconds >
                                                              0
                                                          ? (value) async {
                                                            final newPosition = Duration(
                                                              milliseconds:
                                                                  (value *
                                                                          duration
                                                                              .inMilliseconds)
                                                                      .round(),
                                                            );
                                                            await audioProvider
                                                                .seek(
                                                                  newPosition,
                                                                );
                                                          }
                                                          : null,
                                                  activeColor: Colors.white,
                                                  inactiveColor: Colors.white24,
                                                ),
                                              ),
                                            ),

                                            // Playback speed
                                            GestureDetector(
                                              onTap: () {
                                                // Cycle through speeds: 1x -> 1.25x -> 1.5x -> 2x -> 1x
                                                final currentSpeed =
                                                    audioProvider.playbackSpeed;
                                                double newSpeed;
                                                if (currentSpeed < 1.25) {
                                                  newSpeed = 1.25;
                                                } else if (currentSpeed < 1.5) {
                                                  newSpeed = 1.5;
                                                } else if (currentSpeed < 2.0) {
                                                  newSpeed = 2.0;
                                                } else {
                                                  newSpeed = 1.0;
                                                }
                                                audioProvider.setPlaybackSpeed(
                                                  newSpeed,
                                                );
                                              },
                                              child: Text(
                                                "${audioProvider.playbackSpeed}x",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    giveWidth(12),
                                    showSaveButton(false, () {
                                      bookmarkProvider.toggleBookmark(
                                        widget.article,
                                      );
                                    }, theme),
                                    giveWidth(12),
                                    showShareButton(() {
                                      Share.share(
                                        '${widget.article.title}\n\n${widget.article.link ?? ''}',
                                      );
                                    }, theme),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            /// ARTICLE CONTENT
                            // Display the main article content/description with saved text size
                            Text(
                              _getArticleContent(),
                              style: GoogleFonts.inriaSerif(
                                fontSize: _contentTextSize,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                                color: theme.colorScheme.secondary,
                              ),
                            ),

                            /// PAGE INDICATOR
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  6,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: index == 2 ? 18 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          index == 2
                                              ? config.primaryColorValue
                                              : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Audio Loading Overlay
              const AudioLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }
}
