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
  NewsArticle? _lastPlayedArticle;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTextSize();
    _initializePageView();
    
    // Listen to audio player provider to detect when article changes (auto-advance)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAudioPlayerChanges();
    });
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

  /// Handle page change - dispose audio and update state
  /// Called when user swipes left/right or when auto-advance navigates PageView
  void _handlePageChange(int newIndex) {
    if (newIndex == _currentPageIndex || newIndex < 0 || newIndex >= _articlesList.length) {
      return;
    }
    
    final previousIndex = _currentPageIndex;
    final isSwipingForward = newIndex > previousIndex;
    final swipeDirection = isSwipingForward ? 'RIGHT (next)' : 'LEFT (previous)';
    final currentArticle = _articlesList[previousIndex];
    final newArticle = _articlesList[newIndex];
    
    debugPrint('🔄 Page changed: Index $previousIndex → $newIndex (swipe $swipeDirection)');
    debugPrint('   From: "${currentArticle.title.substring(0, currentArticle.title.length > 40 ? 40 : currentArticle.title.length)}..."');
    debugPrint('   To: "${newArticle.title.substring(0, newArticle.title.length > 40 ? 40 : newArticle.title.length)}..."');
    
    // Mark as swiping to prevent auto-advance from interfering during swipe
    setState(() {
      _isSwiping = true;
    });
    
    // Stop and dispose current audio if playing (user swiped to different article)
    // CRITICAL: Always stop audio when user swipes, regardless of which article is playing
    // This ensures proper audio disposal and prevents conflicts
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.isPlaying || audioProvider.isPaused) {
      debugPrint('🛑 Stopping and disposing audio due to page swipe (user manually navigated)');
      // Stop current audio playback and cancel any pending auto-advance timer
      audioProvider.stop();
    }
    
    // Reset last played article to allow play on new page
    _lastPlayedArticle = null;
    
    // Update current page index (swipe animation is handled by PageView)
    setState(() {
      _currentPageIndex = newIndex;
      _isSwiping = false; // Mark swipe as complete
    });
    
    debugPrint('✅ Page change completed: Now showing article ${newIndex + 1}/${_articlesList.length}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop and dispose audio when page is disposed
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.isPlaying || audioProvider.isPaused) {
      audioProvider.stop();
    }
    _pageController.dispose();
    super.dispose();
  }

  /// Listen to audio player provider changes for auto-navigation (PageView update)
  void _listenToAudioPlayerChanges() {
    // Auto-navigation is handled in the Consumer builder
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
              // Swipe LEFT = previous article (goes to lower index)
              // Swipe RIGHT = next article (goes to higher index)
              PageView.builder(
                controller: _pageController,
                itemCount: _articlesList.length,
                onPageChanged: (index) {
                  // This is called when page animation completes (after swipe or auto-advance)
                  if (index != _currentPageIndex && index >= 0 && index < _articlesList.length) {
                    _handlePageChange(index);
                  }
                },
                itemBuilder: (context, index) {
                  final article = _articlesList[index];
                  return _buildArticlePage(article, config, theme);
                },
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
        // Find the index of this article in our list
        final articleIndex = _articlesList.indexWhere(
          (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );
        
        // Only check for auto-advance when viewing the current page (the page that was previously playing)
        // This prevents duplicate checks on off-screen pages and ensures we only navigate when on the playing page
        final isCurrentVisiblePage = articleIndex >= 0 && articleIndex == _currentPageIndex;
        final articleKey = article.articleId ?? article.title;
        final currentlyPlayingArticle = audioProvider.currentArticle;
        final currentlyPlayingKey = currentlyPlayingArticle?.articleId ?? currentlyPlayingArticle?.title;
        
        // Listen to audio player changes for auto-advance (update PageView)
        // Only check when on the current visible page, audio has advanced, and the displayed article doesn't match the playing article
        if (isCurrentVisiblePage &&
            audioProvider.playlist.isNotEmpty &&
            audioProvider.currentPlaylistIndex >= 0 &&
            audioProvider.currentPlaylistIndex < audioProvider.playlist.length &&
            currentlyPlayingArticle != null &&
            currentlyPlayingKey != articleKey &&
            currentlyPlayingKey != (_lastPlayedArticle?.articleId ?? _lastPlayedArticle?.title) &&
            !audioProvider.playTitleMode &&
            !_isSwiping &&
            mounted &&
            _pageController.hasClients) {
          
          // Auto-advance detected: current article changed (audio advanced to next article)
          final newIndex = audioProvider.currentPlaylistIndex;
          final newArticle = audioProvider.playlist[newIndex];
          final currentArticle = audioProvider.currentArticle!;
          
          // Verify the current article matches the playlist article at current index
          final newArticleKey = newArticle.articleId ?? newArticle.title;
          final currentArticleKey = currentArticle.articleId ?? currentArticle.title;
          final isSameArticle = newArticleKey == currentArticleKey;
          
          // Also check that we haven't already navigated to this article
          final lastPlayedKey = _lastPlayedArticle?.articleId ?? _lastPlayedArticle?.title;
          final hasNotNavigatedYet = lastPlayedKey != newArticleKey;
          
          // Check if new article is in our articles list
          final targetIndex = _articlesList.indexWhere(
            (a) => (a.articleId ?? a.title) == newArticleKey,
          );
          
          if (isSameArticle && hasNotNavigatedYet && targetIndex >= 0 && targetIndex < _articlesList.length && targetIndex != _currentPageIndex) {
            // Update last played article BEFORE navigation to prevent duplicate navigations
            _lastPlayedArticle = newArticle;
            
            debugPrint('🔄 Auto-advance detected: Navigating PageView from index $_currentPageIndex (${article.title.substring(0, article.title.length > 30 ? 30 : article.title.length)}...) to $targetIndex/${_articlesList.length} (${newArticle.title.substring(0, newArticle.title.length > 30 ? 30 : newArticle.title.length)}...)');
            
            // Navigate PageView to the new article (auto-advance)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients && targetIndex != _currentPageIndex) {
                _isSwiping = true; // Prevent duplicate auto-navigation during animation
                _pageController.animateToPage(
                  targetIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ).then((_) {
                  if (mounted) {
                    setState(() {
                      _currentPageIndex = targetIndex;
                      _isSwiping = false;
                    });
                    debugPrint('✅ Auto-advance PageView navigation completed: Now showing article ${targetIndex + 1}/${_articlesList.length}');
                  }
                });
              }
            });
          }
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
                        config.appNameLogo,
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
                  size: 20,
                ),
                giveWidth(4),

                // Play/Pause button
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          if (isCurrentArticle) {
                            // Toggle play/pause for current article
                            await audioProvider.togglePlayPause();
                          } else {
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
                            size: 22,
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
      final newsProvider = context.read<NewsProvider>();
      
      // Check if article is in our current articles list
      final articleIndex = _articlesList.indexWhere(
        (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
      );
      
      if (articleIndex >= 0 && _articlesList.length > 1) {
        // Use current articles list as playlist
        _lastPlayedArticle = article;
        await audioProvider.setPlaylistAndPlay(
          _articlesList,
          articleIndex,
          playTitle: false, // Detail screen plays description only
        );
        debugPrint('🎵 Playing article from PageView playlist: index $articleIndex/${_articlesList.length}');
      } else {
        // Single article or not in list - try to find playlist from news provider
        List<NewsArticle>? playlist;
        int? startIndex;
        
        // Check if article is in breaking news
        final breakingIndex = newsProvider.breakingNews.indexWhere(
          (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );
        if (breakingIndex >= 0) {
          playlist = newsProvider.breakingNews;
          startIndex = breakingIndex;
        } else {
          // Check if article is in flash news (first 5 breaking news)
          final flashNews = newsProvider.breakingNews.take(5).toList();
          final flashIndex = flashNews.indexWhere(
            (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
          );
          if (flashIndex >= 0) {
            playlist = flashNews;
            startIndex = flashIndex;
          } else {
            // Check if article is in today's news
            final todayIndex = newsProvider.todayNews.indexWhere(
              (a) => (a.articleId ?? a.title) == (article.articleId ?? article.title),
            );
            if (todayIndex >= 0) {
              playlist = newsProvider.todayNews;
              startIndex = todayIndex;
            }
          }
        }
        
        if (playlist != null && startIndex != null && startIndex < playlist.length) {
          _lastPlayedArticle = article;
          await audioProvider.setPlaylistAndPlay(
            playlist,
            startIndex,
            playTitle: false,
          );
        } else {
          // No playlist found, play single article
          _lastPlayedArticle = article;
          await audioProvider.playArticleFromUrl(
            article,
            playTitle: false,
          );
        }
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