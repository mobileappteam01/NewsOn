// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/news_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../core/widgets/audio_loading_overlay.dart';
import '../../data/models/news_article.dart';

/// Categories tab - Shows breaking news in carousel design when opened (exact design match)
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late PageController _pageController;
  List<NewsArticle> _articlesList = [];
  int _currentPageIndex = 0;
  NewsArticle? _lastPlayedArticle;
  bool _isSwiping = false;
  bool _isAutoAdvanceAnimating =
      false; // Flag to prevent stopping audio during auto-advance
  DateTime _selectedDate = DateTime.now();
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(
      viewportFraction: 0.85, // Show partial adjacent cards (carousel effect)
    );

    // Initialize breaking news when tab opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        _initializeBreakingNews();
      }
    });
  }

  /// Initialize breaking news when tab opens
  void _initializeBreakingNews() {
    final newsProvider = context.read<NewsProvider>();

    // Mark as initialized
    setState(() {
      _hasInitialized = true;
    });

    // Update articles list based on whether a date is selected
    List<NewsArticle> sourceArticles;
    if (newsProvider.selectedDate != null) {
      // If a date is selected, use todayNews (which contains date-filtered news)
      sourceArticles = newsProvider.todayNews;
      debugPrint(
          '📰 Categories tab: Using date-filtered news (${sourceArticles.length} articles)');
    } else {
      // Otherwise, use breaking news
      sourceArticles = newsProvider.breakingNews;
      debugPrint(
          '📰 Categories tab: Using breaking news (${sourceArticles.length} articles)');
    }

    if (sourceArticles.isNotEmpty) {
      setState(() {
        _articlesList = sourceArticles;
        _currentPageIndex = 0;
        _lastPlayedArticle = null;
        debugPrint(
          '📰 Categories tab: Initialized with ${_articlesList.length} articles',
        );
      });

      // Reset to first page after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients && _articlesList.isNotEmpty) {
          _pageController.jumpToPage(0);
        }
      });
    }

    // Always fetch appropriate news when tab opens
    if (!newsProvider.isLoading) {
      if (newsProvider.selectedDate != null) {
        // Fetch news for selected date
        newsProvider.fetchNewsByDate(newsProvider.selectedDate!, limit: 10);
        debugPrint('📰 Categories tab: Fetching news for selected date...');
      } else {
        // Fetch breaking news
        newsProvider.fetchBreakingNews(limit: 10);
        debugPrint('📰 Categories tab: Fetching breaking news...');
      }
    } else {
      debugPrint('📰 Categories tab: News is already loading...');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    // Stop audio when leaving the tab
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.isPlaying || audioProvider.isPaused) {
      audioProvider.stop();
    }
    super.dispose();
  }

  /// Handle page change - dispose audio and update state
  void _handlePageChange(int newIndex) {
    if (newIndex == _currentPageIndex ||
        newIndex < 0 ||
        newIndex >= _articlesList.length) {
      return;
    }

    // If auto-advance animation is in progress, just update the page index
    // Don't stop audio - it's already playing the next article
    if (_isAutoAdvanceAnimating) {
      debugPrint(
          '🔄 [AUTO-ADVANCE] Page animation completed in categories: $newIndex');
      setState(() {
        _currentPageIndex = newIndex;
      });
      return;
    }

    setState(() {
      _isSwiping = true;
    });

    // Stop current audio if playing (user swiped to different article)
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.isPlaying || audioProvider.isPaused) {
      debugPrint('🛑 Stopping audio due to user swipe in categories tab');
      audioProvider.stop();
    }

    _lastPlayedArticle = null;

    setState(() {
      _currentPageIndex = newIndex;
      _isSwiping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final newsProvider = Provider.of<NewsProvider>(context);

    // Update articles list from appropriate source when it's loaded (listen to provider changes)
    if (_hasInitialized) {
      // Determine which source to use based on date selection
      List<NewsArticle> sourceArticles;
      if (newsProvider.selectedDate != null) {
        // If a date is selected, use todayNews (date-filtered news)
        sourceArticles = newsProvider.todayNews;
      } else {
        // Otherwise, use breaking news
        sourceArticles = newsProvider.breakingNews;
      }

      // Update when source articles are available
      if (sourceArticles.isNotEmpty) {
        if (_articlesList != sourceArticles || _articlesList.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                final previousLength = _articlesList.length;
                _articlesList = sourceArticles;
                // Ensure current page index is valid
                if (_currentPageIndex >= _articlesList.length) {
                  _currentPageIndex = 0;
                  _lastPlayedArticle = null;
                }
                // Reset to first page if articles were just loaded
                if (_articlesList.isNotEmpty) {
                  if (previousLength == 0 && _pageController.hasClients) {
                    // First time loading, jump to page 0
                    _pageController.jumpToPage(0);
                  } else if (_pageController.hasClients &&
                      _currentPageIndex < _articlesList.length) {
                    // Update existing position
                    _pageController.jumpToPage(_currentPageIndex);
                  }
                }
                debugPrint(
                  '📰 Categories tab: Updated with ${_articlesList.length} articles',
                );
              });
            }
          });
        }
      } else if (!newsProvider.isLoading && _articlesList.isNotEmpty) {
        // Source articles were cleared while we have articles, clear our list
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _articlesList = [];
              _currentPageIndex = 0;
              _lastPlayedArticle = null;
              debugPrint(
                '📰 Categories tab: Source articles cleared, resetting articles list',
              );
            });
          }
        });
      }
    }

    return Scaffold(
      // backgroundColor: Colors.black,
      body: Consumer<RemoteConfigProvider>(
        builder: (context, configProvider, child) {
          final config = configProvider.config;

          return Stack(
            children: [
              Column(
                children: [
                  /// 🔹 HEADER: Back button, Logo, Date selector (exact design)
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button (left) - navigates back (but we're in tab, so could do nothing or navigate)
                          // InkWell(
                          //   onTap: () {
                          //     // In tab navigation, back might not make sense, but we can clear state if needed
                          //     // For now, just stop any playing audio
                          //     final audioProvider =
                          //         context.read<AudioPlayerProvider>();
                          //     if (audioProvider.isPlaying ||
                          //         audioProvider.isPaused) {
                          //       audioProvider.stop();
                          //     }
                          //   },
                          //   borderRadius: BorderRadius.circular(25),
                          //   child: Container(
                          //     padding: const EdgeInsets.all(8),
                          //     decoration: const BoxDecoration(
                          //       color: Colors.black45,
                          //       shape: BoxShape.circle,
                          //     ),
                          //     child: const Icon(
                          //       Icons.arrow_back,
                          //       color: Colors.white,
                          //       size: 24,
                          //     ),
                          //   ),
                          // ),

                          // Logo (center)
                          showImage(
                            config.getAppNameLogoForTheme(
                                Theme.of(context).brightness),
                            BoxFit.contain,
                            height: 60,
                            width: 80,
                          ),

                          // Date selector (right) - shows current article's date or current date
                          // _articlesList.isNotEmpty &&
                          //         _currentPageIndex < _articlesList.length
                          //     ? _buildDateSelector(
                          //         context,
                          //         config,
                          //         _articlesList[_currentPageIndex],
                          //       )
                          //     : _buildDateSelector(context, config, null),
                        ],
                      ),
                    ),
                  ),

                  /// 🔹 CATEGORY LABEL: "Headlines" in red (matching exact design)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocalizationHelper.headlines(context),
                        style: GoogleFonts.inter(
                          color: config.primaryColorValue,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  /// 🔹 CAROUSEL: PageView with swipeable cards (showing partial adjacent cards)
                  Expanded(
                    child: _buildLoadingOrContentState(
                        theme, config, newsProvider),
                  ),

                  /// 🔹 PAGE INDICATOR: Dots showing current position (exact design)
                  if (_articlesList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _articlesList.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _currentPageIndex ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index == _currentPageIndex
                                  ? config.primaryColorValue
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                  /// 🔹 AUDIO PLAYER BAR: Red bar with play, progress, time, speed (exact design)
                  // Always show audio player bar if there are articles OR if audio is active
                  // This ensures the player stays visible during auto-advance transitions
                  Consumer<AudioPlayerProvider>(
                    builder: (context, audioProvider, child) {
                      // Determine which article to show:
                      // 1. If audio provider has a current article (playing, paused, or completed), show that
                      // 2. Otherwise, show the current page article
                      final hasArticles = _articlesList.isNotEmpty &&
                          _currentPageIndex < _articlesList.length;

                      // Check if audio is active (has current article, is playing/paused, or has playlist)
                      // This ensures player stays visible during auto-advance delay
                      final hasActiveAudio =
                          audioProvider.currentArticle != null ||
                              audioProvider.isPlaying ||
                              audioProvider.isPaused ||
                              audioProvider.playlist.isNotEmpty;

                      // Always prefer the current article from audio provider if available
                      // This ensures the player shows the correct article during auto-advance transitions
                      NewsArticle? articleToShow;
                      if (audioProvider.currentArticle != null) {
                        // Audio provider has a current article (playing, paused, or completed but not yet cleared)
                        articleToShow = audioProvider.currentArticle;
                      } else if (hasArticles) {
                        // No active audio, use current page article
                        articleToShow = _articlesList[_currentPageIndex];
                      }

                      // Show player bar if:
                      // 1. We have an article to show AND
                      // 2. Either there are articles in the list OR audio is active (to handle transitions)
                      // This ensures player stays visible during auto-advance and completion states
                      if (articleToShow != null &&
                          (hasArticles || hasActiveAudio)) {
                        return _buildAudioPlayerBar(
                          articleToShow,
                          config,
                          theme,
                          audioProvider,
                        );
                      }

                      // No article to show, return empty container (preserves layout)
                      return const SizedBox.shrink();
                    },
                  ),

                  // Bottom safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
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

  /// Build date selector button (matching exact design from image)
  /// Shows current date or article's date in format "16 Sep, 2025"
  Widget _buildDateSelector(
    BuildContext context,
    dynamic config,
    NewsArticle? article,
  ) {
    // Use article's date if available, otherwise use selected date
    DateTime displayDate = _selectedDate;
    if (article != null &&
        article.pubDate != null &&
        article.pubDate!.isNotEmpty) {
      final parsedDate = DateFormatter.parseApiDate(article.pubDate);
      if (parsedDate != null) {
        displayDate = parsedDate;
      }
    }

    return GestureDetector(
      onTap: () async {
        // Show date picker when tapped
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.day,
          helpText: 'Select Date',
          cancelText: 'Cancel',
          confirmText: 'Select',
          fieldLabelText: 'Date',
          fieldHintText: 'Month/Day/Year',
        );

        if (picked != null && picked != _selectedDate) {
          // Normalize the date to remove time components
          final normalizedDate =
              DateTime(picked.year, picked.month, picked.day);
          setState(() => _selectedDate = normalizedDate);

          // Fetch news for the selected date (this will populate todayNews which we can use for headlines)
          if (mounted) {
            debugPrint(
                '📰 Categories tab: Fetching news for date ${DateFormat('yyyy-MM-dd').format(normalizedDate)}');
            await context
                .read<NewsProvider>()
                .fetchNewsByDate(normalizedDate, limit: 10);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.8) ??
              Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat(
                'dd MMM, yyyy',
              ).format(displayDate), // Format: "16 Sep, 2025"
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState(ThemeData theme, dynamic config) {
    return Center(
      child: CircularProgressIndicator(color: config.primaryColorValue),
    );
  }

  /// Build no news state
  Widget _buildNoNewsState(ThemeData theme) {
    return Center(
      child: Text(
        LocalizationHelper.noNewsAvailable(context),
        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
      ),
    );
  }

  /// Build loading or content state based on date selection
  Widget _buildLoadingOrContentState(
      ThemeData theme, dynamic config, NewsProvider newsProvider) {
    // Determine which source to check based on date selection
    List<NewsArticle> sourceArticles;
    if (newsProvider.selectedDate != null) {
      // If a date is selected, check todayNews
      sourceArticles = newsProvider.todayNews;
    } else {
      // Otherwise, check breaking news
      sourceArticles = newsProvider.breakingNews;
    }

    // Show loading if provider is loading and source is empty
    if (newsProvider.isLoading && sourceArticles.isEmpty) {
      return _buildLoadingState(theme, config);
    }

    // Show no news if source is empty and not loading
    if (sourceArticles.isEmpty) {
      return _buildNoNewsState(theme);
    }

    // Show no news if our articles list is empty
    if (_articlesList.isEmpty) {
      return _buildNoNewsState(theme);
    }

    // Show carousel
    return _buildCarousel(config, theme, newsProvider);
  }

  /// Build carousel with PageView (exact design match)
  Widget _buildCarousel(
    dynamic config,
    ThemeData theme,
    NewsProvider newsProvider,
  ) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _articlesList.length,
      onPageChanged: (index) {
        if (index != _currentPageIndex &&
            index >= 0 &&
            index < _articlesList.length) {
          _handlePageChange(index);
        }
      },
      itemBuilder: (context, index) {
        final article = _articlesList[index];
        return _buildNewsCard(article, config, theme, index);
      },
    );
  }

  /// Build a single news card (matching exact design from image)
  Widget _buildNewsCard(
    NewsArticle article,
    dynamic config,
    ThemeData theme,
    int index,
  ) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        // Auto-advance logic (similar to detail page)
        final articleIndex = _articlesList.indexWhere(
          (a) =>
              (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );

        final isCurrentVisiblePage =
            articleIndex >= 0 && articleIndex == _currentPageIndex;
        final articleKey = article.articleId ?? article.title;
        final currentlyPlayingArticle = audioProvider.currentArticle;
        final currentlyPlayingKey = currentlyPlayingArticle?.articleId ??
            currentlyPlayingArticle?.title;

        // Auto-advance navigation logic
        // Note: playTitleMode is true when using reading preference (categories tab uses playTitle: true)
        if (isCurrentVisiblePage &&
            audioProvider.playlist.isNotEmpty &&
            audioProvider.currentPlaylistIndex >= 0 &&
            audioProvider.currentPlaylistIndex <
                audioProvider.playlist.length &&
            currentlyPlayingArticle != null &&
            currentlyPlayingKey != articleKey &&
            currentlyPlayingKey !=
                (_lastPlayedArticle?.articleId ?? _lastPlayedArticle?.title) &&
            audioProvider.playTitleMode ==
                true && // Categories tab uses reading preference (playTitle: true)
            !_isSwiping &&
            mounted &&
            _pageController.hasClients) {
          final newIndex = audioProvider.currentPlaylistIndex;
          final newArticle = audioProvider.playlist[newIndex];
          final currentArticle = audioProvider.currentArticle!;

          final newArticleKey = newArticle.articleId ?? newArticle.title;
          final currentArticleKey =
              currentArticle.articleId ?? currentArticle.title;
          final isSameArticle = newArticleKey == currentArticleKey;

          final lastPlayedKey =
              _lastPlayedArticle?.articleId ?? _lastPlayedArticle?.title;
          final hasNotNavigatedYet = lastPlayedKey != newArticleKey;

          final targetIndex = _articlesList.indexWhere(
            (a) => (a.articleId ?? a.title) == newArticleKey,
          );

          if (isSameArticle &&
              hasNotNavigatedYet &&
              targetIndex >= 0 &&
              targetIndex < _articlesList.length &&
              targetIndex != _currentPageIndex) {
            _lastPlayedArticle = newArticle;

            debugPrint(
              '🔄 Auto-advance in categories: Navigating to article $targetIndex/${_articlesList.length}',
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _pageController.hasClients &&
                  targetIndex != _currentPageIndex &&
                  !_isAutoAdvanceAnimating) {
                // Set flag BEFORE animation to prevent _handlePageChange from stopping audio
                _isAutoAdvanceAnimating = true;
                _isSwiping = true;
                _pageController
                    .animateToPage(
                  targetIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )
                    .then((_) {
                  if (mounted) {
                    setState(() {
                      _currentPageIndex = targetIndex;
                      _isSwiping = false;
                      _isAutoAdvanceAnimating = false;
                    });
                    debugPrint(
                        '✅ [AUTO-ADVANCE] Categories page synced to article ${targetIndex + 1}/${_articlesList.length}');
                  }
                }).catchError((e) {
                  _isAutoAdvanceAnimating = false;
                  _isSwiping = false;
                });
              }
            });
          }
        }

        // Card with carousel effect (viewportFraction shows partial adjacent cards)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image (full card)
                  CachedNetworkImage(
                    imageUrl: article.imageUrl ?? article.sourceIcon ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),

                  // Gradient overlay (darker at bottom for text readability)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Content overlay (bottom) - EXACT DESIGN MATCH
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "Hot News" tag in red (bottom-left) - EXACT DESIGN
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: config.primaryColorValue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              LocalizationHelper.hotNews(context),
                              style: GoogleFonts.inter(
                                color: config.primaryColorValue,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Article title (overlay on image) - EXACT DESIGN MATCH
                          Text(
                            article.title,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build audio player bar (matching exact design from image)
  Widget _buildAudioPlayerBar(
    NewsArticle article,
    dynamic config,
    ThemeData theme,
    AudioPlayerProvider audioProvider,
  ) {
    final isCurrentArticle = audioProvider.currentArticle != null &&
        (audioProvider.currentArticle!.articleId ??
                audioProvider.currentArticle!.title) ==
            (article.articleId ?? article.title);

    final isPlaying = isCurrentArticle && audioProvider.isPlaying;
    final isLoading = isCurrentArticle && audioProvider.isLoading;

    // Calculate progress
    final duration = audioProvider.duration;
    final position = audioProvider.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // Format time as MM:SS
    final positionText = audioProvider.formatDuration(position);
    final durationText = audioProvider.formatDuration(duration);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: config.primaryColorValue, // Red bar - EXACT DESIGN
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Play/Pause button (left) - EXACT DESIGN
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () async {
                      if (isCurrentArticle) {
                        await audioProvider.togglePlayPause();
                      } else {
                        await _playArticle(article, audioProvider);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.all(6),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),

            const SizedBox(width: 10),

            // Current time (MM:SS format) - before progress bar - EXACT DESIGN
            Text(
              positionText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(width: 10),

            // Progress slider (middle) - EXACT DESIGN
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.2),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: duration.inMilliseconds > 0
                      ? (value) async {
                          final newPosition = Duration(
                            milliseconds:
                                (value * duration.inMilliseconds).round(),
                          );
                          await audioProvider.seek(newPosition);
                        }
                      : null,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Total duration (MM:SS format) - after progress bar - EXACT DESIGN
            Text(
              durationText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(width: 10),

            // Playback speed button (right) - EXACT DESIGN "1.5x"
            GestureDetector(
              onTap: () {
                final currentSpeed = audioProvider.playbackSpeed;
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
                audioProvider.setPlaybackSpeed(newSpeed);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  "${audioProvider.playbackSpeed}x",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Play article with playlist setup (respects user's reading preference)
  Future<void> _playArticle(
    NewsArticle article,
    AudioPlayerProvider audioProvider,
  ) async {
    try {
      if (_articlesList.isEmpty) return;

      // Check if article is in our current articles list (breaking news)
      final articleIndex = _articlesList.indexWhere(
        (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
      );

      if (articleIndex >= 0 && _articlesList.length > 1) {
        // Use current breaking news list as playlist
        // playTitle: true means use stored reading preference (title only / description only / full news)
        _lastPlayedArticle = article;
        await audioProvider.setPlaylistAndPlay(
          _articlesList,
          articleIndex,
          playTitle:
              true, // Use user's reading preference (AudioPlayerProvider handles it)
        );
        debugPrint(
          '🎵 Playing breaking news from categories tab: index $articleIndex/${_articlesList.length} (using reading preference)',
        );
      } else {
        // Single article or not in list
        // playTitle: true means use stored reading preference (title only / description only / full news)
        _lastPlayedArticle = article;
        await audioProvider.playArticleFromUrl(
          article,
          playTitle:
              true, // Use user's reading preference (AudioPlayerProvider handles it)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  bool get wantKeepAlive => true;
}
