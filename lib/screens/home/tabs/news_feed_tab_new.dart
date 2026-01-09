// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/screens/news_detail/news_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../core/widgets/language_selector_dialog.dart';
import '../../../core/widgets/news_feed_shimmer.dart';
import '../../../widgets/news_grid_views.dart';
import '../../../data/models/news_article.dart';
import '../../../core/constants/api_constants.dart';
import '../../view_all/breaking_news_view_all_screen.dart';
import '../../view_all/today_news_view_all_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';

class NewsFeedTabNew extends StatefulWidget {
  final List<String> selectedCategories;
  final List newsList;

  const NewsFeedTabNew({
    super.key,
    required this.selectedCategories,
    required this.newsList,
  });

  @override
  State<NewsFeedTabNew> createState() => _NewsFeedTabNewState();
}

class _NewsFeedTabNewState extends State<NewsFeedTabNew>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PageController _breakingNewsController = PageController(
    viewportFraction: 0.75,
  );
  final PageController _flashNewsController = PageController(
    viewportFraction: 0.9,
  );

  String _selectedCategory = 'All';
  DateTime _selectedDate = DateTime.now();

  // Get dynamic categories from API config, with 'All' as first option
  List<String> get categories {
    final apiCategories = ApiConstants.categories;
    // Capitalize first letter of each category for display
    final formattedCategories =
        apiCategories.map((cat) {
          if (cat.isEmpty) return cat;
          return cat[0].toUpperCase() + cat.substring(1);
        }).toList();
    return ['All', ...formattedCategories];
  }

  @override
  void initState() {
    super.initState();
    // Fetch today's news on initialization with limit of 5
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NewsProvider>().fetchNewsByDate(_selectedDate, limit: 5);
        // Fetch breaking news with limit of 10
        context.read<NewsProvider>().fetchBreakingNews(limit: 10);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _breakingNewsController.dispose();
    _flashNewsController.dispose();
    super.dispose();
  }

  showHeadingText(String text, ThemeData theme, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.playfair(
              color: theme.colorScheme.secondary,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            LocalizationHelper.viewAll(context),
            style: GoogleFonts.inter(
              color: Color(0xFFC70000),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final remoteConfig = context.read<RemoteConfigProvider>().config;
    final newsProvider = context.watch<NewsProvider>();

    // Show shimmer while breaking news is loading initially
    if (newsProvider.isLoading && newsProvider.breakingNews.isEmpty) {
      return const NewsFeedShimmer();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildRefreshButton(
        context,
        newsProvider,
        remoteConfig,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header: logo + date + language
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  showImage(
                    remoteConfig.appNameLogo,
                    BoxFit.contain,
                    height: 60,
                    width: 80,
                  ),
                  Row(
                    children: [
                      _buildDatePicker(context),
                      const SizedBox(width: 12),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) {
                          return GestureDetector(
                            onTap: () => showLanguageSelectorDialog(context),
                            child: showImage(
                              remoteConfig.languageImg,
                              BoxFit.contain,
                              height: 20,
                              width: 30,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Refresh breaking news
                  await newsProvider.fetchBreakingNews();
                  // Refresh today's news
                  await newsProvider.fetchNewsByDate(_selectedDate);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Section title - Breaking News (Centered)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          LocalizationHelper.breakingNews(context),
                          style: GoogleFonts.playfair(
                            color: Color(0xFFE31E24),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Breaking News CarouselSlider
                    if (newsProvider.isLoading &&
                        newsProvider.breakingNews.isEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 400,
                          child: _buildBreakingNewsShimmer(theme),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: CarouselSlider.builder(
                          itemCount:
                              newsProvider.breakingNews.isNotEmpty
                                  ? newsProvider.breakingNews.length.clamp(
                                    0,
                                    10,
                                  ) // Limit to 10 on home page
                                  : widget.newsList.length.clamp(0, 10),
                          itemBuilder: (context, index, realIndex) {
                            final article =
                                newsProvider.breakingNews.isNotEmpty
                                    ? newsProvider.breakingNews[index]
                                    : _mapToArticle(widget.newsList[index]);
                            return _buildBreakingNewsCard(
                              context,
                              article,
                              remoteConfig,
                              index, // Pass index for playlist
                            );
                          },
                          options: CarouselOptions(
                            height: 400,
                            viewportFraction: 0.85,
                            initialPage: 0,
                            enableInfiniteScroll: false,
                            reverse: false,
                            autoPlay: false,
                            enlargeCenterPage: true,
                            enlargeFactor: 0.3,
                            onPageChanged: (index, reason) {
                              // Optional: Handle page change
                            },
                            scrollDirection: Axis.horizontal,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Category tabs
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 36,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = _selectedCategory == category;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedCategory = category);
                                  if (category != 'All') {
                                    // Convert display name back to API format (lowercase)
                                    final apiCategory = category.toLowerCase();
                                    context
                                        .read<NewsProvider>()
                                        .fetchNewsByCategory(apiCategory);
                                  } else {
                                    // If "All" is selected, fetch breaking news
                                    context
                                        .read<NewsProvider>()
                                        .fetchBreakingNews();
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(0xFFE31E24)
                                            : Colors.black,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Today heading (dynamic based on selected date)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: showHeadingText(
                          _getDateHeadingText(
                            newsProvider.selectedDate ?? _selectedDate,
                          ),
                          theme,
                          onViewAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => TodayNewsViewAllScreen(
                                      selectedDate:
                                          newsProvider.selectedDate ??
                                          _selectedDate,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Today list items (from API)
                    if (newsProvider.isLoadingToday)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildTodayNewsShimmer(theme),
                              );
                            },
                            childCount: 3, // Show 3 shimmer items
                          ),
                        ),
                      )
                    else if (newsProvider.todayNews.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              LocalizationHelper.noNewsForDate(context),
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final article = newsProvider.todayNews[index];
                              return NewsGridView(
                                key: ValueKey(
                                  'today_${article.articleId ?? index}',
                                ),
                                type: 'listview',
                                newsDetails: article,
                                onListenTapped: () async {
                                  try {
                                    final newsProvider =
                                        context.read<NewsProvider>();
                                    final todayNews = newsProvider.todayNews;

                                    // Find the index of current article in today's news
                                    final startIndex = todayNews.indexWhere(
                                      (a) =>
                                          (a.articleId ?? a.title) ==
                                          (article.articleId ?? article.title),
                                    );

                                    if (startIndex >= 0 &&
                                        startIndex < todayNews.length) {
                                      // Set playlist with all today's news and start from clicked article
                                      await context
                                          .read<AudioPlayerProvider>()
                                          .setPlaylistAndPlay(
                                            todayNews,
                                            startIndex,
                                            playTitle: true,
                                          );
                                    } else {
                                      // Fallback: play single article
                                      await context
                                          .read<AudioPlayerProvider>()
                                          .playArticleFromUrl(
                                            article,
                                            playTitle: true,
                                          );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error playing audio: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                onSaveTapped: () {
                                  context.read<NewsProvider>().toggleBookmark(
                                    article,
                                  );
                                },
                                onNewsTapped: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => NewsDetailScreen(
                                            article: article,
                                          ),
                                    ),
                                  );
                                },
                                onShareTapped: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (c) {
                                      return showShareModalBottomSheet(context);
                                    },
                                  );
                                },
                              );
                            },
                            childCount: newsProvider.todayNews.length.clamp(
                              0,
                              5,
                            ),
                          ), // Limit to 5 on home page
                        ),
                      ),

                    // Flash news section title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: showHeadingText(
                          LocalizationHelper.flashNews(context),
                          theme,
                          onViewAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const BreakingNewsViewAllScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Flash news PageView (no nested sliver)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _flashNewsController,
                          itemCount: newsProvider.breakingNews.length.clamp(
                            0,
                            5,
                          ), // Limit to 5 on home page
                          itemBuilder: (context, index) {
                            final data = newsProvider.breakingNews[index];
                            return NewsGridView(
                              key: ValueKey('flash_$index'),
                              type: 'bannerview',
                              newsDetails: data,
                              onListenTapped: () async {
                                try {
                                  final newsProvider =
                                      context.read<NewsProvider>();
                                  final flashNews =
                                      newsProvider.breakingNews
                                          .take(5)
                                          .toList();

                                  // Find the index of current article in flash news
                                  final startIndex = flashNews.indexWhere(
                                    (a) =>
                                        (a.articleId ?? a.title) ==
                                        (data.articleId ?? data.title),
                                  );

                                  if (startIndex >= 0 &&
                                      startIndex < flashNews.length) {
                                    // Set playlist with all flash news and start from clicked article
                                    await context
                                        .read<AudioPlayerProvider>()
                                        .setPlaylistAndPlay(
                                          flashNews,
                                          startIndex,
                                          playTitle: true,
                                        );
                                  } else {
                                    // Fallback: play single article
                                    await context
                                        .read<AudioPlayerProvider>()
                                        .playArticleFromUrl(
                                          data,
                                          playTitle: true,
                                        );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error playing audio: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              onSaveTapped: () {},
                              onNewsTapped: () async {
                                NewsArticle newsArticle = await getNewsDetail();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => NewsDetailScreen(
                                          article: newsArticle,
                                        ),
                                  ),
                                );
                              },
                              onShareTapped: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (c) {
                                    return showShareModalBottomSheet(context);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Live Cricket Score Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            showHeadingText(
                              LocalizationHelper.liveCricketScore(context),
                              theme,
                            ),
                            const SizedBox(height: 12),
                            // card
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE31E24),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'World T20 - T20 16 of 45',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // India row
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: Colors.orange,
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '🇮🇳',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'IND',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        '172-8 (20)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Pakistan row
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: Colors.green,
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '🇵🇰',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'PAK',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        '152/3 (15.4)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  showMatchVS("AUS", "IND", remoteConfig),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 24,
                            ), // bottom spacing for nav
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build refresh button
  Widget _buildRefreshButton(
    BuildContext context,
    NewsProvider newsProvider,
    RemoteConfigModel remoteConfig,
  ) {
    final isRefreshing = newsProvider.isLoading || newsProvider.isLoadingToday;

    return FloatingActionButton(
      onPressed:
          isRefreshing
              ? null
              : () async {
                // Refresh breaking news
                await newsProvider.fetchBreakingNews();
                // Refresh today's news
                await newsProvider.fetchNewsByDate(_selectedDate);
              },
      backgroundColor: remoteConfig.primaryColorValue,
      child:
          isRefreshing
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : const Icon(Icons.refresh, color: Colors.white),
    );
  }

  /// Build breaking news card with exact design
  Widget _buildBreakingNewsCard(
    BuildContext context,
    NewsArticle article,
    RemoteConfigModel config, [
    int? articleIndex,
  ]) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(article: article),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              _buildCardImage(article),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),

              // Content at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Hot News" label
                      Text(
                        LocalizationHelper.hotNews(context),
                        style: GoogleFonts.inter(
                          color: Color(0xFFE31E24),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title - split into multiple lines
                      _buildTitleText(article.title),
                      const SizedBox(height: 16),

                      // Listen button at bottom right
                      Align(
                        alignment: Alignment.bottomRight,
                        child: showListenButton(config, () async {
                          try {
                            final newsProvider = context.read<NewsProvider>();
                            final breakingNews =
                                newsProvider.breakingNews.isNotEmpty
                                    ? newsProvider.breakingNews
                                    : widget.newsList
                                        .map((e) => _mapToArticle(e))
                                        .toList();

                            // Find the index of current article in the list
                            final startIndex =
                                articleIndex ??
                                breakingNews.indexWhere(
                                  (a) =>
                                      (a.articleId ?? a.title) ==
                                      (article.articleId ?? article.title),
                                );

                            if (startIndex >= 0 &&
                                startIndex < breakingNews.length) {
                              // Set playlist with all breaking news and start from clicked article
                              await context
                                  .read<AudioPlayerProvider>()
                                  .setPlaylistAndPlay(
                                    breakingNews,
                                    startIndex,
                                    playTitle: true,
                                  );
                            } else {
                              // Fallback: play single article
                              await context
                                  .read<AudioPlayerProvider>()
                                  .playArticleFromUrl(article, playTitle: true);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error playing audio: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // Bookmark icon at top right
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    context.read<NewsProvider>().toggleBookmark(article);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      article.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build card image with proper handling
  Widget _buildCardImage(NewsArticle article) {
    final imageUrl = article.imageUrl ?? article.sourceIcon ?? '';

    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 50,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey[600],
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          ),
        );
      },
    );
  }

  /// Build title text split into multiple lines
  Widget _buildTitleText(String title) {
    // Split title into words and create multiple lines
    final words = title.split(' ');
    if (words.length <= 3) {
      return Text(
        title,
        style: GoogleFonts.playfair(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Try to split into 2-3 lines for better visual effect
    final midPoint = (words.length / 2).ceil();
    final firstLine = words.sublist(0, midPoint).join(' ');
    final secondLine = words.sublist(midPoint).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstLine,
          style: GoogleFonts.playfair(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        if (secondLine.isNotEmpty)
          Text(
            secondLine,
            style: GoogleFonts.playfair(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
      ],
    );
  }

  /// Build shimmer for breaking news carousel
  Widget _buildBreakingNewsShimmer(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build shimmer for today's news list items
  Widget _buildTodayNewsShimmer(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: MediaQuery.of(context).size.width * 0.5,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.3,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: convert dynamic map (from sample newsList) to a NewsArticle-like object
  // If you already have NewsArticle objects from provider, you won't need this
  NewsArticle _mapToArticle(Map m) {
    return NewsArticle(
      title: m['headLines'] ?? '',
      imageUrl: m['img'] as String?,
      link: m['link'] as String?,
      category: m['category'] != null ? [m['category'].toString()] : null,
    );
  }

  /// Get heading text based on date
  String _getDateHeadingText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return LocalizationHelper.today(context);
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return LocalizationHelper.yesterday(context);
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null && picked != _selectedDate) {
          setState(() => _selectedDate = picked);
          // Fetch news for the selected date
          if (mounted) {
            context.read<NewsProvider>().fetchNewsByDate(picked);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('dd MMM').format(_selectedDate),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

showShareModalBottomSheet(context) {
  RemoteConfigModel config = RemoteConfigModel();
  return Stack(
    children: [
      SizedBox(
        height: 180,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 4; i++)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        i == 0
                            ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(
                                3.1416,
                              ), // 180° flip horizontally
                              child: Icon(
                                Icons.reply_outlined,
                                size: 24,
                                color: config.primaryColorValue,
                              ),
                            )
                            : Icon(
                              i == 1
                                  ? Icons.bookmark_border_outlined
                                  : i == 2
                                  ? Icons.block
                                  : Icons.flag_outlined,
                              color: config.primaryColorValue,
                            ),
                        giveWidth(12),
                        Text(
                          i == 0
                              ? "Share"
                              : i == 1
                              ? "Bookmark"
                              : i == 2
                              ? "Block relevant News"
                              : "Report",
                          style: TextStyle(color: config.primaryColorValue),
                        ),
                      ],
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
