// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import '../../core/utils/localization_helper.dart';
import '../../data/services/news_share_service.dart';
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
import '../../core/widgets/detail_carousel_ad_page.dart';
import '../../core/utils/detail_carousel_ad_helper.dart';
import '../../data/services/interaction_service.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;

  /// Snapshot of the feed list the user was browsing (preserves swipe order).
  final List<NewsArticle>? articles;

  /// Index of [article] inside [articles].
  final int? initialIndex;

  const NewsDetailScreen({
    super.key,
    required this.article,
    this.articles,
    this.initialIndex,
  });

  /// Stable identity for matching the same story across lists.
  static String articleKey(NewsArticle article) {
    return article.newsId ?? article.articleId ?? article.title;
  }

  static int indexOfArticle(List<NewsArticle> articles, NewsArticle article) {
    final key = articleKey(article);
    if (key.isEmpty) return -1;
    return articles.indexWhere((a) => articleKey(a) == key);
  }

  /// Open detail with the exact list + index from the feed the user tapped.
  static void open(
    BuildContext context, {
    required NewsArticle article,
    List<NewsArticle>? articles,
    int? initialIndex,
  }) {
    final snapshot = articles != null ? List<NewsArticle>.from(articles) : null;
    var index = initialIndex ??
        (snapshot != null ? indexOfArticle(snapshot, article) : 0);
    if (index < 0) index = 0;
    if (snapshot != null && snapshot.isNotEmpty && index >= snapshot.length) {
      index = snapshot.length - 1;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(
          article: article,
          articles: snapshot,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late List<NewsArticle> _articlesList;
  late List<DetailCarouselItem> _carouselPages;
  late int _initialIndex;
  double _contentTextSize = AppConstants.defaultTextSize;

  /// PageView index (may point at an article or an ad page).
  int _currentCarouselIndex = 0;
  bool _isAnimating = false; // Prevent duplicate animations
  AudioPlayerProvider? _audioProvider; // Cached for safe use in dispose

  // Periodic timer for state synchronization
  Timer? _stateSyncTimer;
  bool _didRefreshStateOnEnter = false;

  final InteractionService _interactionService = InteractionService();
  final Set<String> _trackedOpenKeys = {};
  final Set<String> _trackedReadKeys = {};
  DateTime? _articleVisibleSince;
  int? _visibleArticleIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTextSize();
    _initializePageView();
    _startStateSyncTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final articleIdx = _articleIndexForCarousel(_currentCarouselIndex);
      if (articleIdx != null) _trackVisibleArticle(articleIdx);
    });
  }

  int? _articleIndexForCarousel(int carouselIndex) =>
      DetailCarouselAdHelper.articleIndexForCarousel(
        _carouselPages,
        carouselIndex,
      );

  int _carouselIndexForArticle(int articleIndex) =>
      DetailCarouselAdHelper.carouselIndexForArticle(
        _carouselPages,
        articleIndex,
      );

  int? get _currentArticleIndex =>
      _articleIndexForCarousel(_currentCarouselIndex);

  void _rebuildCarouselPages({int? preferredArticleIndex}) {
    _carouselPages = DetailCarouselAdHelper.buildPages(_articlesList.length);
    final articleIdx = preferredArticleIndex ??
        _articleIndexForCarousel(_currentCarouselIndex) ??
        0;
    _currentCarouselIndex = _carouselIndexForArticle(articleIdx.clamp(
      0,
      (_articlesList.isEmpty ? 0 : _articlesList.length - 1),
    ));
  }

  String _articleTrackingKey(NewsArticle article) {
    return NewsDetailScreen.articleKey(article);
  }

  int _indexOfArticle(List<NewsArticle> articles, NewsArticle article) {
    return NewsDetailScreen.indexOfArticle(articles, article);
  }

  /// Initialize PageView with article list based on source
  void _initializePageView() {
    if (widget.articles != null && widget.articles!.isNotEmpty) {
      _articlesList = List<NewsArticle>.from(widget.articles!);
      var startIndex =
          widget.initialIndex ?? _indexOfArticle(_articlesList, widget.article);
      if (startIndex < 0) startIndex = 0;
      if (startIndex >= _articlesList.length) {
        startIndex = _articlesList.length - 1;
      }
      _initialIndex = startIndex;
      _rebuildCarouselPages(preferredArticleIndex: _initialIndex);
      _pageController = PageController(initialPage: _currentCarouselIndex);
      debugPrint(
          '📋 Initialized PageView from feed snapshot (${_articlesList.length} articles, ${_carouselPages.length} pages) at article $_initialIndex / carousel $_currentCarouselIndex');
      return;
    }

    _initializeFromProvider();
  }

  /// Fallback when no feed snapshot was passed (deep links, legacy routes).
  void _initializeFromProvider() {
    final newsProvider = context.read<NewsProvider>();
    final tapped = widget.article;

    final candidates = <List<NewsArticle>>[
      newsProvider.categoryNews,
      newsProvider.todayNews,
      newsProvider.articles,
      newsProvider.breakingNews,
    ];

    for (final list in candidates) {
      if (list.isEmpty) continue;
      final idx = _indexOfArticle(list, tapped);
      if (idx >= 0) {
        _articlesList = List<NewsArticle>.from(list);
        _initialIndex = idx;
        _rebuildCarouselPages(preferredArticleIndex: _initialIndex);
        _pageController = PageController(initialPage: _currentCarouselIndex);
        debugPrint(
            '📋 Initialized PageView from provider (${_articlesList.length} articles, ${_carouselPages.length} pages) at article $_initialIndex / carousel $_currentCarouselIndex');
        return;
      }
    }

    _articlesList = [tapped];
    _initialIndex = 0;
    _rebuildCarouselPages(preferredArticleIndex: 0);
    _pageController = PageController(initialPage: 0);
    debugPrint('📋 Initialized PageView with single article');
  }

  void _trackVisibleArticle(int index) {
    if (index < 0 || index >= _articlesList.length) return;

    final article = _articlesList[index];
    final key = _articleTrackingKey(article);

    if (_visibleArticleIndex != null &&
        _visibleArticleIndex != index &&
        _visibleArticleIndex! < _articlesList.length) {
      _sendReadForArticle(_articlesList[_visibleArticleIndex!]);
    }

    _visibleArticleIndex = index;
    _articleVisibleSince = DateTime.now();

    if (!_trackedOpenKeys.contains(key)) {
      _trackedOpenKeys.add(key);
      unawaited(_interactionService.trackOpen(article));
    }
  }

  void _sendReadForArticle(NewsArticle article) {
    final key = _articleTrackingKey(article);
    if (_trackedReadKeys.contains(key)) return;

    final since = _articleVisibleSince;
    final duration =
        since != null ? DateTime.now().difference(since).inSeconds : 0;

    _trackedReadKeys.add(key);
    unawaited(_interactionService.trackRead(article, duration: duration));
  }

  /// Start periodic timer for state synchronization
  void _startStateSyncTimer() {
    _stateSyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _audioProvider != null) {
        _checkAndSyncAutoAdvance(_audioProvider!);
      }
    });
  }

  /// Handle user swipe - STOP audio and update page
  void _onUserSwipe(int newCarouselIndex) {
    if (newCarouselIndex == _currentCarouselIndex ||
        newCarouselIndex < 0 ||
        newCarouselIndex >= _carouselPages.length) {
      return;
    }

    debugPrint(
        '👆 [USER SWIPE] Page: $_currentCarouselIndex → $newCarouselIndex');

    // STOP audio when user swipes (including onto/off an ad page)
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.hasCurrentArticle) {
      debugPrint('🛑 Stopping audio due to user swipe');
      audioProvider.stop();
    }

    setState(() {
      _currentCarouselIndex = newCarouselIndex;
    });

    final articleIdx = _articleIndexForCarousel(newCarouselIndex);
    if (articleIdx != null) {
      _trackVisibleArticle(articleIdx);
    } else if (_visibleArticleIndex != null &&
        _visibleArticleIndex! >= 0 &&
        _visibleArticleIndex! < _articlesList.length) {
      // Landed on an ad — close out the previous article's read timer.
      _sendReadForArticle(_articlesList[_visibleArticleIndex!]);
    }
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

    final targetCarousel = _carouselIndexForArticle(audioIndex);
    final currentArticle = _currentArticleIndex ?? -1;

    // Only sync when audio has *advanced forward* past the article we're on.
    if (audioIndex > currentArticle) {
      debugPrint(
          '🔄 [AUTO-ADVANCE] Audio article $audioIndex, carousel $_currentCarouselIndex → $targetCarousel');

      if (mounted &&
          _pageController.hasClients &&
          !_isAnimating &&
          targetCarousel != _currentCarouselIndex) {
        _isAnimating = true;
        _pageController
            .animateToPage(
          targetCarousel,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        )
            .then((_) {
          if (mounted) {
            setState(() {
              _currentCarouselIndex = targetCarousel;
              _isAnimating = false;
            });
            _trackVisibleArticle(audioIndex);
            debugPrint(
                '✅ [AUTO-ADVANCE] PageView synced to article ${audioIndex + 1}/${_articlesList.length}');
          }
        }).catchError((e) {
          _isAnimating = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioProvider = context.read<AudioPlayerProvider>();
    // When opening or returning to this screen, refresh provider state so the
    // control bar shows current play state and progress (e.g. same article
    // still playing from mini player).
    if (!_didRefreshStateOnEnter) {
      _didRefreshStateOnEnter = true;
      // Defer to after this frame: refreshState() calls notifyListeners(),
      // which must not run during the build/dependency phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _audioProvider?.refreshState();
      });
    }
  }

  @override
  void dispose() {
    if (_visibleArticleIndex != null &&
        _visibleArticleIndex! >= 0 &&
        _visibleArticleIndex! < _articlesList.length) {
      _sendReadForArticle(_articlesList[_visibleArticleIndex!]);
    }
    WidgetsBinding.instance.removeObserver(this);
    _stateSyncTimer?.cancel();
    // Do NOT stop audio when leaving screen: playback continues so the user
    // can keep listening via the mini player; re-opening this article will
    // show the current player state via Consumer<AudioPlayerProvider>.
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final audioProvider = _audioProvider;
    if (audioProvider == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - syncing audio state');
        _loadTextSize();
        _syncAudioStateOnResume(audioProvider);
        break;

      case AppLifecycleState.paused:
        debugPrint('📱 App paused - keeping audio state');
        // Audio should continue playing in background
        break;

      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive - preparing for potential pause');
        break;

      case AppLifecycleState.detached:
        debugPrint('📱 App detached - cleaning up resources');
        break;

      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden - audio should continue in background');
        break;
    }
  }

  /// Sync audio state when app resumes to ensure UI consistency
  void _syncAudioStateOnResume(AudioPlayerProvider audioProvider) {
    if (!mounted) return;

    // Force refresh the audio provider state to ensure UI sync
    audioProvider.refreshState();

    // If we have a current article, ensure the UI reflects the correct state
    if (audioProvider.hasCurrentArticle) {
      final currentArticle = audioProvider.currentArticle;
      final currentArticleId =
          currentArticle?.articleId ?? currentArticle?.title;
      final pageArticleIdx = _currentArticleIndex;
      final pageArticle =
          pageArticleIdx != null ? _articlesList[pageArticleIdx] : null;
      final pageArticleId = pageArticle?.articleId ?? pageArticle?.title;

      debugPrint(
          '🔄 Sync check - Current: $currentArticleId, Page: $pageArticleId');
      debugPrint(
          '🔄 Audio state - Playing: ${audioProvider.isPlaying}, Paused: ${audioProvider.isPaused}');

      // If the same article is playing, ensure UI is synchronized
      if (currentArticleId == pageArticleId) {
        debugPrint('✅ Same article detected - UI should be in sync');
      } else {
        debugPrint('⚠️ Different article detected - may need UI update');
      }
    }

    // Trigger UI update to ensure consistency
    setState(() {});
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

  Future<void> _leaveDetail() async {
    if (_visibleArticleIndex != null &&
        _visibleArticleIndex! >= 0 &&
        _visibleArticleIndex! < _articlesList.length) {
      _sendReadForArticle(_articlesList[_visibleArticleIndex!]);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveDetail();
      },
      child: Scaffold(
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
                    itemCount: _carouselPages.length,
                    onPageChanged: (index) {
                      if (index == _currentCarouselIndex) return;

                      if (_isAnimating) {
                        debugPrint(
                            '🔄 [AUTO-ADVANCE] Page animation completed: $index');
                        setState(() {
                          _currentCarouselIndex = index;
                        });
                        final articleIdx = _articleIndexForCarousel(index);
                        if (articleIdx != null) {
                          _trackVisibleArticle(articleIdx);
                        }
                        return;
                      }

                      final audioProvider = context.read<AudioPlayerProvider>();
                      final articleIdx = _articleIndexForCarousel(index);
                      final isAutoAdvance = articleIdx != null &&
                          audioProvider.currentPlaylistIndex == articleIdx &&
                          (audioProvider.isPlaying ||
                              audioProvider.hasCurrentArticle) &&
                          !audioProvider.playTitleMode;

                      if (isAutoAdvance) {
                        debugPrint(
                            '🔄 [AUTO-ADVANCE] Page synced: carousel $index / article $articleIdx');
                        setState(() {
                          _currentCarouselIndex = index;
                        });
                        _trackVisibleArticle(articleIdx);
                      } else {
                        _onUserSwipe(index);
                      }
                    },
                    itemBuilder: (context, index) {
                      final page = _carouselPages[index];
                      if (page is DetailAdPageItem) {
                        return DetailCarouselAdPage(
                          key: ValueKey('detail_ad_${page.adSlotIndex}'),
                          slotIndex: page.adSlotIndex,
                          onClose: _leaveDetail,
                          appLogoUrl:
                              config.getAppNameLogoForTheme(Brightness.dark),
                        );
                      }

                      final articleItem = page as DetailArticlePageItem;
                      final article = _articlesList[articleItem.articleIndex];
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
          (a) =>
              (a.articleId ?? a.title) == (article.articleId ?? article.title),
        );

        // Only check auto-advance for the currently visible article page
        if (articleIndex == _currentArticleIndex) {
          _checkAndSyncAutoAdvance(audioProvider);
        }

        // Fixed hero header + scrollable article body only (industry pattern).
        return Column(
          children: [
            /// 🔹 FIXED HEADER — image + exact bands below status bar:
            /// 80 chrome · 180 category+title · remaining (~80) source/date
            Builder(
              builder: (context) {
                final topInset = MediaQuery.paddingOf(context).top;
                return SizedBox(
                  height: _heroImageHeight + topInset,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: article.imageUrl ?? article.sourceIcon ?? '',
                        height: _heroImageHeight + topInset,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            newsOnImageFallback(
                          width: double.infinity,
                          height: _heroImageHeight + topInset,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.18, 0.48, 1.0],
                            colors: [
                              Color(0xB3000000),
                              Colors.transparent,
                              Colors.transparent,
                              Color(0xE6000000),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topInset),
                          SizedBox(
                            height: _heroChromeHeight,
                            child: _buildHeroChrome(config, article),
                          ),
                          // SizedBox(
                          //   height: _heroTitleBandHeight,
                          //   child: Padding(
                          //     padding:
                          //         const EdgeInsets.symmetric(horizontal: 20),
                          //     child: _buildHeroTitleBand(article, config),
                          //   ),
                          // ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _buildHeroFooterBand(article),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            /// 🔹 SCROLLABLE CONTENT ONLY
            Expanded(
              child: Material(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAudioControlBar(
                        article,
                        config,
                        theme,
                        audioProvider,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _getArticleContent(article),
                        style: GoogleFonts.inriaSerif(
                          fontSize: _contentTextSize,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      _buildPageIndicator(config, theme),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Exact hero layout bands (must sum with footer to [_heroImageHeight]).
  static const double _heroImageHeight = 340;
  static const double _heroChromeHeight = 80;
  static const double _heroTitleBandHeight = 210;
  // Remaining footer band: 340 - 80 - 210 = 50

  /// Back · logo · share — locked to [_heroChromeHeight] (full 80px usable).
  Widget _buildHeroChrome(dynamic config, NewsArticle article) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HeroChromeButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 42,
            color: Colors.white,
            onTap: _leaveDetail,
          ),
          const SizedBox(width: 10),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: showImage(
              config.getAppNameLogoForTheme(Brightness.dark),
              BoxFit.contain,
              height: 60,
              width: 80,
            ),
          ),
          const Spacer(),
          _HeroChromeButton(
            icon: Icons.share_rounded,
            size: 42,
            color: theme.colorScheme.primary,
            onTap: () {
              unawaited(_interactionService.trackShare(article));
              NewsShareService.shareArticle(
                article,
                curiousCta: LocalizationHelper.shareNewsCuriousCta(context),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Category + title — locked to [_heroTitleBandHeight] (180).
  Widget _buildHeroTitleBand(NewsArticle article, dynamic config) {
    final titleText = '"${article.title}"';
    final categoryText = article.category?.first ?? 'Politics';

    return LayoutBuilder(
      builder: (context, constraints) {
        final categoryStyle = GoogleFonts.inter(
          color: config.primaryColorValue,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          height: 1.3,
        );
        final titleStyle = GoogleFonts.playfairDisplay(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          height: 1.3,
        );

        const categoryGap = 8.0;
        final categoryH = _measureTextHeight(
          categoryText,
          categoryStyle,
          constraints.maxWidth,
          maxLines: 1,
        );
        final titleMaxH = (constraints.maxHeight - categoryH - categoryGap)
            .clamp(24.0, 180.0);
        final titleSize = _fitTitleFontSize(
          text: titleText,
          baseStyle: titleStyle,
          maxWidth: constraints.maxWidth,
          maxHeight: titleMaxH,
        );

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoryText,
                style: categoryStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: categoryGap),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    titleText + titleText + titleText,
                    style: titleStyle.copyWith(
                      fontSize: titleSize,
                      height: 1.3,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Source + published — fills remaining hero space (80px).
  Widget _buildHeroFooterBand(NewsArticle article) {
    final sourceLine =
        '${LocalizationHelper.sourceLabel(context, article.sourceName ?? 'NewsOn')}'
        '${(article.creator != null && article.creator!.isNotEmpty) ? ' | ${LocalizationHelper.authorLabel(context, article.creator![0])}' : ''}';
    final publishedLine =
        '${LocalizationHelper.publishedLabel(context, article.pubDate != null ? DateFormatter.formatDate(DateFormatter.parseApiDate(article.pubDate) ?? DateTime.now()) : DateFormatter.formatDate(DateTime.now()))} (${_getTimeAgo(article)})';

    final sourceStyle = GoogleFonts.inter(
      color: Colors.white.withOpacity(0.9),
      fontSize: 12,
      height: 1.35,
    );
    final publishedStyle = GoogleFonts.inter(
      color: Colors.white.withOpacity(0.8),
      fontSize: 11,
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  sourceLine,
                  style: sourceStyle,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                publishedLine,
                style: publishedStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  double _measureTextHeight(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '…' : null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  /// Largest Playfair size (≤22) that keeps [text] inside the title band.
  double _fitTitleFontSize({
    required String text,
    required TextStyle baseStyle,
    required double maxWidth,
    required double maxHeight,
    double minSize = 12,
    double maxSize = 22,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return minSize;

    var low = minSize;
    var high = maxSize;
    var best = minSize;

    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(fontSize: mid, height: 1.3),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return best;
  }

  static const int _maxPageIndicatorDots = 12;

  Widget _buildPageIndicator(dynamic config, ThemeData theme) {
    final total = _articlesList.length;
    if (total <= 1) {
      return const SizedBox(height: 20);
    }

    final activeArticle = _currentArticleIndex ?? _visibleArticleIndex ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: total <= _maxPageIndicatorDots
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    total,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == activeArticle ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == activeArticle
                            ? config.primaryColorValue
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              )
            : Text(
                '${activeArticle + 1} / $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  /// Build enhanced audio control bar with live duration display
  Widget _buildAudioControlBar(
    NewsArticle article,
    dynamic config,
    ThemeData theme,
    AudioPlayerProvider audioProvider,
  ) {
    final voiceEnabled =
        context.watch<RemoteConfigProvider>().isVoiceFeaturesEnabled;
    if (!voiceEnabled) {
      return const SizedBox.shrink();
    }

    final isCurrentArticle = audioProvider.currentArticle != null &&
        (audioProvider.currentArticle!.newsId ??
                audioProvider.currentArticle!.articleId ??
                audioProvider.currentArticle!.title) ==
            (article.newsId ?? article.articleId ?? article.title);

    final isPlaying = isCurrentArticle && audioProvider.isPlaying;
    final isLoading = isCurrentArticle && audioProvider.isLoading;

    // Calculate progress
    final duration = audioProvider.duration;
    final position = audioProvider.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // Format duration strings
    final formattedPosition = _formatDuration(position);
    final formattedDuration = _formatDuration(duration);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isLargeScreen = screenWidth >= 768;

        // Responsive sizing
        final controlBarHeight = isLargeScreen ? 60.0 : 50.0;
        final iconSize = isLargeScreen ? 28.0 : 24.0;
        final playButtonSize = isLargeScreen ? 32.0 : 25.0;
        final fontSize = isSmallScreen ? 11.0 : (isLargeScreen ? 13.0 : 12.0);
        final spacing = isSmallScreen ? 8.0 : 12.0;

        return Container(
          height: controlBarHeight,
          child: Row(
            children: [
              // Main audio control bar
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 16 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: config.primaryColorValue,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Audio icon with subtle animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(width: spacing),

                      // Play/Pause button with enhanced visual feedback
                      GestureDetector(
                        onTap: isLoading
                            ? null
                            : () async {
                                if (isCurrentArticle) {
                                  print(
                                      "🎵 [DETAIL] Toggling play/pause for current article");
                                  await audioProvider.togglePlayPause();
                                } else {
                                  print("_playArticle");
                                  await _playArticle(article, audioProvider);
                                }
                              },
                        child: Container(
                          padding: EdgeInsets.all(isLargeScreen ? 4 : 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: playButtonSize,
                                  height: playButtonSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: playButtonSize,
                                ),
                        ),
                      ),
                      SizedBox(width: spacing),

                      // Duration display and progress section
                      if (isCurrentArticle && duration.inMilliseconds > 0) ...[
                        // Current position
                        Text(
                          formattedPosition,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: spacing / 2),

                        // Progress slider with enhanced styling
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: isLargeScreen ? 3 : 2,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: isLargeScreen ? 6 : 4,
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                overlayRadius: isLargeScreen ? 12 : 8,
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
                                            (value * duration.inMilliseconds)
                                                .round(),
                                      );
                                      await audioProvider.seek(newPosition);
                                    }
                                  : null,
                            ),
                          ),
                        ),

                        SizedBox(width: spacing / 2),
                        // Total duration
                        Text(
                          formattedDuration,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: spacing),

                        // Speed control with enhanced styling
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
                            padding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 8 : 6,
                              vertical: isLargeScreen ? 4 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "${audioProvider.playbackSpeed}x",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Center(
                            child: Text(
                              isCurrentArticle && isLoading
                                  ? LocalizationHelper.loading(context)
                                  : LocalizationHelper.tapToPlayArticle(
                                      context),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // SizedBox(width: spacing),

              // Action buttons column
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bookmark button
                  Builder(
                    builder: (context) {
                      final bookmarkProvider =
                          Provider.of<BookmarkProvider>(context, listen: true);
                      final isBookmarked =
                          bookmarkProvider.isBookmarked(article);
                      return GestureDetector(
                        onTap: () async {
                          try {
                            final newStatus =
                                await bookmarkProvider.toggleBookmark(article);
                            if (newStatus) {
                              unawaited(
                                _interactionService.trackBookmark(article),
                              );
                            }
                            if (mounted) {
                              final newsProvider = Provider.of<NewsProvider>(
                                  context,
                                  listen: false);
                              newsProvider.updateArticleBookmarkStatus(
                                  article, newStatus);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newStatus
                                        ? LocalizationHelper.addedToBookmarks(
                                            context)
                                        : LocalizationHelper
                                            .removedFromBookmarks(context),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationHelper.error(
                                      context, e.toString())),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(isLargeScreen ? 10 : 8),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: isBookmarked
                                ? const Color(0xFFE31E24)
                                : theme.colorScheme.secondary,
                            size: iconSize,
                          ),
                        ),
                      );
                    },
                  ),
                  // SizedBox(height: spacing / 2),
                  // Share button
                  GestureDetector(
                    onTap: () {
                      unawaited(_interactionService.trackShare(article));
                      NewsShareService.shareArticle(
                        article,
                        curiousCta: LocalizationHelper.shareNewsCuriousCta(
                          context,
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(isLargeScreen ? 10 : 8),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.share,
                        color: theme.colorScheme.secondary,
                        size: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Format duration to MM:SS or HH:MM:SS format
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
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
        debugPrint(
            '🎵 [DETAIL] Playing content audio: index $articleIndex/${_articlesList.length}');
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
            content: Text(
                LocalizationHelper.failedToPlayAudio(context, e.toString())),
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

/// Compact circular control for the detail hero toolbar.
class _HeroChromeButton extends StatelessWidget {
  const _HeroChromeButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconSize = (size * 0.48).clamp(16.0, 20.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}
