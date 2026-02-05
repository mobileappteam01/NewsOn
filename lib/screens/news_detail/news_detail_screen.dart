// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
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
import '../../providers/news_provider.dart';
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
  late PageController _pageController;
  late List<NewsArticle> _articlesList;
  late int _initialIndex;
  double _contentTextSize = AppConstants.defaultTextSize;
  int _currentPageIndex = 0;
  bool _isAnimating = false; // Prevent duplicate animations

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTextSize();
    _initializePageView();
  }

  /// Initialize PageView with article list based on source
  void _initializePageView() {
    final newsProvider = context.read<NewsProvider>();
    List<NewsArticle> articlesList;
    int startIndex = 0;

    // Check if article is in breaking news
    final breakingIndex = newsProvider.breakingNews.indexWhere(
      (a) => (a.articleId ?? a.title) == (widget.article.articleId ?? widget.article.title),
    );
    
    if (breakingIndex >= 0) {
      // Use all breaking news for swipeable list
      articlesList = newsProvider.breakingNews;
      startIndex = breakingIndex;
      debugPrint('📋 Initialized PageView with breaking news (${articlesList.length} articles) at index $startIndex');
    } else {
      // Check if article is in flash news (first 5 breaking news)
      final flashNews = newsProvider.breakingNews.take(5).toList();
      final flashIndex = flashNews.indexWhere(
        (a) => (a.articleId ?? a.title) == (widget.article.articleId ?? widget.article.title),
      );
      
      if (flashIndex >= 0) {
        // Use flash news (first 5 breaking news) for swipeable list
        articlesList = flashNews;
        startIndex = flashIndex;
        debugPrint('📋 Initialized PageView with flash news (${articlesList.length} articles) at index $startIndex');
      } else {
        // Check if article is in today's news
        final todayIndex = newsProvider.todayNews.indexWhere(
          (a) => (a.articleId ?? a.title) == (widget.article.articleId ?? widget.article.title),
        );
        
        if (todayIndex >= 0) {
          articlesList = newsProvider.todayNews;
          startIndex = todayIndex;
          debugPrint('📋 Initialized PageView with today news (${articlesList.length} articles) at index $startIndex');
        } else {
          // Article not found in any list, use single article
          articlesList = [widget.article];
          startIndex = 0;
          debugPrint('📋 Initialized PageView with single article');
        }
      }
    }

    _articlesList = articlesList;
    _initialIndex = startIndex;
    _currentPageIndex = _initialIndex;
    
    // Initialize PageController with initial index
    _pageController = PageController(initialPage: _initialIndex);
  }

  /// Handle user swipe - STOP audio and update page
  void _onUserSwipe(int newIndex) {
    if (newIndex == _currentPageIndex || newIndex < 0 || newIndex >= _articlesList.length) {
      return;
    }
    
    debugPrint('👆 [USER SWIPE] Page: $_currentPageIndex → $newIndex');
    
    // STOP audio when user swipes
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.hasCurrentArticle) {
      debugPrint('🛑 Stopping audio due to user swipe');
      audioProvider.stop();
    }
    
    setState(() {
      _currentPageIndex = newIndex;
    });
  }

  /// Check if audio has auto-advanced and sync PageView
  void _checkAndSyncAutoAdvance(AudioPlayerProvider audioProvider) {
    // Skip if in list view mode (playTitleMode=true) - only handle detail screen (playTitleMode=false)
    if (audioProvider.playTitleMode) return;
    
    // Skip if no playlist or invalid index
    if (audioProvider.playlist.isEmpty) return;
    
    final audioIndex = audioProvider.currentPlaylistIndex;
    if (audioIndex < 0 || audioIndex >= audioProvider.playlist.length) return;
    if (audioIndex >= _articlesList.length) return;
    
    // Check if audio has moved to a different article than current page
    // This happens when auto-advance plays the next article
    if (audioIndex != _currentPageIndex) {
      debugPrint('🔄 [AUTO-ADVANCE] Audio at $audioIndex, page at $_currentPageIndex - syncing...');
      
      // Animate to new page (prevent duplicate animations)
      if (mounted && _pageController.hasClients && !_isAnimating) {
        _isAnimating = true;
        _pageController.animateToPage(
          audioIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ).then((_) {
          if (mounted) {
            setState(() {
              _currentPageIndex = audioIndex;
              _isAnimating = false;
            });
            debugPrint('✅ [AUTO-ADVANCE] PageView synced to article ${audioIndex + 1}/${_articlesList.length}');
          }
        }).catchError((e) {
          _isAnimating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop audio when leaving screen
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.hasCurrentArticle) {
      audioProvider.stop();
    }
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<RemoteConfigProvider>(
        builder: (context, configProvider, child) {
          final config = configProvider.config;

          return Stack(
            children: [
              // PageView for swipeable navigation
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Detect user scroll/swipe start
                  if (notification is ScrollStartNotification) {
                    if (notification.dragDetails != null) {
                      // User initiated scroll (not programmatic)
                      debugPrint('👆 User started swiping');
                    }
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _articlesList.length,
                  onPageChanged: (index) {
                    if (index != _currentPageIndex) {
                      // If we're animating (auto-advance triggered the animation), don't treat as user swipe
                      if (_isAnimating) {
                        debugPrint('🔄 [AUTO-ADVANCE] Page animation completed: $index');
                        setState(() {
                          _currentPageIndex = index;
                        });
                        return;
                      }
                      
                      // Check if this is auto-advance (audio provider index matches) or user swipe
                      final audioProvider = context.read<AudioPlayerProvider>();
                      final isAutoAdvance = audioProvider.currentPlaylistIndex == index &&
                          (audioProvider.isPlaying || audioProvider.hasCurrentArticle) &&
                          !audioProvider.playTitleMode;
                      
                      if (isAutoAdvance) {
                        // Auto-advance - just update page index, don't stop audio
                        debugPrint('🔄 [AUTO-ADVANCE] Page synced: $index');
                        setState(() {
                          _currentPageIndex = index;
                        });
                      } else {
                        // User swipe - stop audio
                        _onUserSwipe(index);
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final article = _articlesList[index];
                    return _buildArticlePage(article, config, theme);
                  },
                ),
              ),

              // Audio Loading Overlay
              const AudioLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  /// Build a single article page
  Widget _buildArticlePage(
    NewsArticle article,
    dynamic config,
    ThemeData theme,
  ) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        // Get current article index
        final articleIndex = _articlesList.indexWhere(
          (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );
        
        // Only check auto-advance for the currently visible page
        if (articleIndex == _currentPageIndex) {
          _checkAndSyncAutoAdvance(audioProvider);
        }

        return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          /// 🔹 HEADER IMAGE + OVERLAY
          Stack(
            children: [
              // Background image
              CachedNetworkImage(
                imageUrl: article.imageUrl ?? article.sourceIcon ?? '',
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
                        config.getAppNameLogoForTheme(Theme.of(context).brightness),
                        BoxFit.contain,
                        height: 60,
                        width: 80,
                      ),
                      const Spacer(),
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
                      article.category?.first ?? "Politics",
                      style: GoogleFonts.inter(
                        color: config.primaryColorValue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${article.title}"',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getTimeAgo(article),
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
          Container( 
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 22,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// AUDIO CONTROL BAR
                _buildAudioControlBar(article, config, theme, audioProvider),
                const SizedBox(height: 20),

                /// ARTICLE CONTENT
                Text(
                  _getArticleContent(article),
                  style: GoogleFonts.inriaSerif(
                    fontSize: _contentTextSize,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: theme.colorScheme.secondary,
                  ),
                ),

                /// PAGE INDICATOR
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
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
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  /// Build audio control bar
  Widget _buildAudioControlBar(
    NewsArticle article,
    dynamic config,
    ThemeData theme,
    AudioPlayerProvider audioProvider,
  ) {
    final isCurrentArticle = audioProvider.currentArticle != null &&
        (audioProvider.currentArticle!.articleId ?? audioProvider.currentArticle!.title) ==
            (article.articleId ?? article.title);

    final isPlaying = isCurrentArticle && audioProvider.isPlaying;
    final isLoading = isCurrentArticle && audioProvider.isLoading;

    // Calculate progress
    final duration = audioProvider.duration;
    final position = audioProvider.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
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
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                // Audio icon
                const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                giveWidth(4),

                // Play/Pause button
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          if (isCurrentArticle) {
                            print("🎵 [DETAIL] Toggling play/pause for current article");
                            // Toggle play/pause for current article
                            await audioProvider.togglePlayPause();
                          } else {
                            print("_playArticle");
                            // Play this article (description only for detail screen)
                            await _playArticle(article, audioProvider);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                ),

                giveWidth(4),

                // Progress slider
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: duration.inMilliseconds > 0
                          ? (value) async {
                              final newPosition = Duration(
                                milliseconds: (value * duration.inMilliseconds).round(),
                              );
                              await audioProvider.seek(newPosition);
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
                  child: Text(
                    "${audioProvider.playbackSpeed}x",
                    style: const TextStyle(
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
        // Bookmark button
        Builder(
          builder: (context) {
            final bookmarkProvider = Provider.of<BookmarkProvider>(context, listen: true);
            final isBookmarked = bookmarkProvider.isBookmarked(article);
            return showSaveButton(
              isBookmarked,
              () async {
                try {
                  final newStatus = await bookmarkProvider.toggleBookmark(article);
                  if (mounted) {
                    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
                    newsProvider.updateArticleBookmarkStatus(article, newStatus);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newStatus ? 'Added to bookmarks' : 'Removed from bookmarks',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              theme,
            );
          },
        ),
        giveWidth(12),
        // Share button
        showShareButton(() {
          Share.share('${article.title}\n\n${article.link ?? ''}');
        }, theme),
      ],
    );
  }

  /// Play article with playlist setup
  Future<void> _playArticle(
    NewsArticle article,
    AudioPlayerProvider audioProvider,
  ) async {
    try {
      // Check if article is in our current articles list
      final articleIndex = _articlesList.indexWhere(
        (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
      );
      
      if (articleIndex >= 0 && _articlesList.length > 1) {
        // Use current articles list as playlist
        await audioProvider.setPlaylistAndPlay(
          _articlesList,
          articleIndex,
          playTitle: false, // Detail screen plays CONTENT audio only
        );
        debugPrint('🎵 [DETAIL] Playing content audio: index $articleIndex/${_articlesList.length}');
      } else {
        // Single article - play directly
        await audioProvider.playArticleFromUrl(
          article,
          playTitle: false, // Detail screen plays CONTENT audio only
        );
        debugPrint('🎵 [DETAIL] Playing single article content audio');
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

  /// Get the article content text to display
  String _getArticleContent(NewsArticle article) {
    if (article.content != null &&
        article.content!.isNotEmpty &&
        article.content != 'ONLY AVAILABLE IN PAID PLANS') {
      return article.content!;
    }
    if (article.description != null && article.description!.isNotEmpty) {
      return article.description!;
    }
    return 'White House trade adviser Peter Navarro accused India of helping finance Russia\'s war in Ukraine through continued oil imports, describing the conflict as "Modi\'s war."';
  }

  /// Get relative time string from article's pubDate
  String _getTimeAgo(NewsArticle article) {
    if (article.pubDate == null || article.pubDate!.isEmpty) {
      return 'Just now';
    }

    final dateTime = DateFormatter.parseApiDate(article.pubDate);
    if (dateTime == null) {
      return 'Just now';
    }

    return DateFormatter.getRelativeTime(dateTime);
  }
}