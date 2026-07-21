// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/screens/news_detail/news_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/ad_placement_helper.dart';
import '../../../core/widgets/inline_feed_ad.dart';
import '../../../data/services/ad_service.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../core/widgets/news_share_bottom_sheet.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/font_manager.dart';
import '../../../core/widgets/language_selector_dialog.dart';
import '../../../core/widgets/region_selector_bottom_sheet.dart';
import '../../../providers/region_provider.dart';
import '../../../core/widgets/news_feed_shimmer.dart';
import '../../../widgets/news_grid_views.dart';
import '../../../data/models/news_article.dart';
import '../../../core/widgets/news_article_image.dart';
import '../../../data/services/storage_service.dart';
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
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final int _newsLimit = 20;

  int _todayNewsPage = 1;
  bool _isLoadingMoreToday = false;
  bool _hasMoreTodayNews = true;

  List<NewsArticle> _allTodayNews = [];

  int _categoryNewsPage = 1;
  bool _isLoadingMoreCategory = false;
  bool _hasMoreCategoryNews = true;

  List<NewsArticle> _allCategoryNews = [];

  String? _lastNewsLanguageCode;

  /// FAB refresh spinner — provider flags clear on cache hit, so we track the
  /// full refresh sequence locally.
  bool _isFabRefreshing = false;

  @override
  void initState() {
    super.initState();

    _hydrateOfflineLists();

    _scrollController.addListener(_onScrollPagination);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final languageProvider = context.read<LanguageProvider>();
      _lastNewsLanguageCode = languageProvider.getApiLanguageCode();
      languageProvider.addListener(_onNewsLanguageChanged);

      final newsProvider = context.read<NewsProvider>();
      final regionProvider = context.read<RegionProvider>();

      await regionProvider.initialize();
      if (regionProvider.hasAppliedRegion) {
        await newsProvider.setSavedRegion(regionProvider.appliedRegion);
        setState(() {
          _allTodayNews = [];
          _allCategoryNews = [];
        });
      }

      await newsProvider.fetchCategories();
      await newsProvider.fetchBreakingNews(limit: 10);
      await _loadInitialTodayNews();
    });
  }

  /// Show last cached lists immediately when reopening offline.
  void _hydrateOfflineLists() {
    final today = StorageService.getTodayNewsCache();
    if (today.isNotEmpty) {
      _allTodayNews = today;
    }
    final category = StorageService.getArticlesCache();
    if (category.isNotEmpty) {
      _allCategoryNews = category;
    }
  }

  void _onScrollPagination() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_selectedCategory == 'All') {
        if (!_isLoadingMoreToday && _hasMoreTodayNews) {
          _loadMoreTodayNews();
        }
      } else {
        if (!_isLoadingMoreCategory && _hasMoreCategoryNews) {
          _loadMoreCategoryNews();
        }
      }
    }
  }

  Future<void> _loadInitialTodayNews({bool allowCacheFallback = true}) async {
    // Today's cache is only valid for the current calendar day.
    final canUseCache = allowCacheFallback && _isViewingToday;
    try {
      final newsProvider = context.read<NewsProvider>();

      await newsProvider.fetchNewsByDate(
        _selectedDate,
        limit: _newsLimit,
        page: 1,
      );

      if (!mounted) return;

      final results = newsProvider.todayNews;
      setState(() {
        _allTodayNews = results.isNotEmpty
            ? results
            : (newsProvider.hasRegionFilter || !canUseCache
                ? <NewsArticle>[]
                : StorageService.getTodayNewsCache());
        _todayNewsPage = 1;
        _hasMoreTodayNews = _allTodayNews.length == _newsLimit;
      });
    } catch (e) {
      debugPrint('⚠️ _loadInitialTodayNews: $e');
      if (!mounted) return;
      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.hasRegionFilter || !canUseCache) {
        setState(() {
          _allTodayNews = [];
          _hasMoreTodayNews = false;
        });
        return;
      }
      final cached = StorageService.getTodayNewsCache();
      if (cached.isNotEmpty) {
        setState(() {
          _allTodayNews = cached;
          _hasMoreTodayNews = false;
        });
      }
    }
  }

  Future<void> _loadMoreTodayNews() async {
    if (_isLoadingMoreToday || !_hasMoreTodayNews) return;

    setState(() {
      _isLoadingMoreToday = true;
    });

    try {
      final newsProvider = context.read<NewsProvider>();
      final languageProvider = context.read<LanguageProvider>();

      final language = languageProvider.getApiLanguageCode();

      final nextPage = _todayNewsPage + 1;

      final dateString =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final region = newsProvider.savedRegion;
      final response = await newsProvider.repository.fetchTodayNews(
        date: dateString,
        language: language,
        limit: _newsLimit,
        page: nextPage,
        country: region.country,
        state: region.state,
        district: region.district,
      );

      if (!mounted) return;

      setState(() {
        _allTodayNews.addAll(response.results);
        _todayNewsPage = nextPage;
        _hasMoreTodayNews = response.results.length == _newsLimit;
        _isLoadingMoreToday = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreToday = false;
      });
    }
  }

  /// True when the selected date is the current calendar day.
  bool get _isViewingToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadInitialCategoryNews(
    String category, {
    bool allowCacheFallback = true,
  }) async {
    // Cached category articles are not date-specific, so only fall back to
    // them when the user is viewing today's feed.
    final canUseCache = allowCacheFallback && _isViewingToday;
    try {
      final newsProvider = context.read<NewsProvider>();

      await newsProvider.fetchCategoryNews(
        category,
        limit: _newsLimit,
        date: _selectedDate,
      );

      if (!mounted) return;

      final results = newsProvider.categoryNews;
      setState(() {
        _allCategoryNews = results.isNotEmpty
            ? results
            : (newsProvider.hasRegionFilter || !canUseCache
                ? <NewsArticle>[]
                : StorageService.getArticlesCache());
        _categoryNewsPage = 1;
        _hasMoreCategoryNews = _allCategoryNews.length == _newsLimit;
      });
    } catch (e) {
      debugPrint('⚠️ _loadInitialCategoryNews: $e');
      if (!mounted) return;
      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.hasRegionFilter || !canUseCache) {
        setState(() {
          _allCategoryNews = [];
          _hasMoreCategoryNews = false;
        });
        return;
      }
      final cached = StorageService.getArticlesCache();
      if (cached.isNotEmpty) {
        setState(() {
          _allCategoryNews = cached;
          _hasMoreCategoryNews = false;
        });
      }
    }
  }

  Future<void> _loadMoreCategoryNews() async {
    if (_isLoadingMoreCategory || !_hasMoreCategoryNews) return;

    setState(() {
      _isLoadingMoreCategory = true;
    });

    try {
      final newsProvider = context.read<NewsProvider>();
      final languageProvider = context.read<LanguageProvider>();

      final language = languageProvider.getApiLanguageCode();

      final nextPage = _categoryNewsPage + 1;

      final dateString =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final region = newsProvider.savedRegion;
      final response = await newsProvider.repository.fetchNewsByCategory(
        _selectedCategory.toLowerCase(),
        language: language,
        date: dateString,
        limit: _newsLimit,
        page: nextPage,
        country: region.country,
        state: region.state,
        district: region.district,
      );

      if (!mounted) return;

      setState(() {
        _allCategoryNews.addAll(response.results);
        _categoryNewsPage = nextPage;
        _hasMoreCategoryNews = response.results.length == _newsLimit;
        _isLoadingMoreCategory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreCategory = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      context.read<LanguageProvider>().removeListener(_onNewsLanguageChanged);
    } catch (_) {}
    _scrollController.dispose();
    _breakingNewsController.dispose();
    _flashNewsController.dispose();
    super.dispose();
  }

  void _onNewsLanguageChanged() {
    final languageProvider = context.read<LanguageProvider>();
    final newCode = languageProvider.getApiLanguageCode();
    if (newCode == _lastNewsLanguageCode) return;
    _lastNewsLanguageCode = newCode;
    _reloadFeedContent(allowCacheFallback: false);
  }

  /// Clears local lists and refetches breaking + today/category news.
  Future<void> _reloadFeedContent({bool allowCacheFallback = true}) async {
    if (!mounted) return;

    setState(() {
      _allTodayNews = [];
      _allCategoryNews = [];
      _todayNewsPage = 1;
      _categoryNewsPage = 1;
      _hasMoreTodayNews = true;
      _hasMoreCategoryNews = true;
    });

    _scrollToTop();

    final newsProvider = context.read<NewsProvider>();
    await newsProvider.fetchBreakingNews(limit: 10);

    if (!mounted) return;

    if (_selectedCategory == 'All') {
      await _loadInitialTodayNews(allowCacheFallback: allowCacheFallback);
    } else {
      await _loadInitialCategoryNews(
        _selectedCategory.toLowerCase(),
        allowCacheFallback: allowCacheFallback,
      );
    }
  }

  Future<void> _onRegionApplied() async {
    final regionProvider = context.read<RegionProvider>();
    final newsProvider = context.read<NewsProvider>();

    await newsProvider.setSavedRegion(regionProvider.appliedRegion);
    await _reloadFeedContent(allowCacheFallback: false);
  }

  Future<void> _onRegionReset() async {
    final newsProvider = context.read<NewsProvider>();
    await newsProvider.clearSavedRegion();
    await _reloadFeedContent();
  }

  String _emptyFeedMessage(BuildContext context, NewsProvider newsProvider) {
    if (newsProvider.hasRegionFilter) {
      return LocalizationHelper.noNewsForRegion(context);
    }
    return LocalizationHelper.noNewsForDate(context);
  }

  /// Scroll to top of the page with smooth animation
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget showHeadingText(String text, ThemeData theme) {
    return Text(
      text,
      style: FontManager.headline5.copyWith(
        color: theme.colorScheme.secondary,
        fontSize: 20,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final remoteConfig = context.read<RemoteConfigProvider>().config;

    // Use Consumer to rebuild when NewsProvider changes
    // The key on NewsFeedTabNew in IndexedStack ensures stable widget identity
    return Consumer<NewsProvider>(
      builder: (context, newsProvider, child) {
        // Show shimmer while breaking news is loading initially
        if (newsProvider.isLoading && newsProvider.breakingNews.isEmpty) {
          return const NewsFeedShimmer();
        }

        return _buildScaffold(context, theme, remoteConfig, newsProvider);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme,
    dynamic remoteConfig,
    NewsProvider newsProvider,
  ) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildRefreshButton(
        context,
        newsProvider,
        remoteConfig,
      ),
      // bottomNavigationBar: const BannerAdContainer(),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header: logo + date + language
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _scrollToTop,
                    child: showImage(
                      remoteConfig.getAppNameLogoForTheme(theme.brightness),
                      BoxFit.contain,
                      height: 60,
                      width: 80,
                    ),
                  ),
                  Row(
                    children: [
                      _buildDatePicker(context),
                      const SizedBox(width: 8),
                      Consumer<RegionProvider>(
                        builder: (context, regionProvider, _) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              Icons.public,
                              size: 22,
                              color: regionProvider.hasAppliedRegion
                                  ? remoteConfig.primaryColorValue
                                  : theme.colorScheme.onSurface,
                            ),
                            tooltip: LocalizationHelper.selectRegionTooltip(
                              context,
                            ),
                            onPressed: () async {
                              final regionProvider =
                                  context.read<RegionProvider>();
                              if (!regionProvider.isInitialized) {
                                await regionProvider.initialize();
                              }
                              if (!context.mounted) return;
                              showRegionSelectorBottomSheet(
                                context,
                                onApplied: _onRegionApplied,
                                onReset: _onRegionReset,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) {
                          return Tooltip(
                            message:
                                'News language: ${languageProvider.newsLanguageName}',
                            child: GestureDetector(
                              onTap: () =>
                                  showNewsLanguageSelectorDialog(context),
                              child: showImage(
                                remoteConfig.languageImg,
                                BoxFit.contain,
                                height: 20,
                                width: 30,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Category tabs - Dynamic from API
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 36,
                child: Builder(
                  builder: (context) {
                    // Build category list: "All" + dynamic categories from API
                    final apiCategories = newsProvider.categories;
                    final categoryNames = <String>['All'];
                    for (final cat in apiCategories) {
                      // Capitalize first letter for display
                      final displayName = cat.name.isNotEmpty
                          ? cat.name[0].toUpperCase() + cat.name.substring(1)
                          : cat.name;
                      categoryNames.add(displayName);
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      itemCount: categoryNames.length,
                      itemBuilder: (context, index) {
                        final category = categoryNames[index];
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            setState(
                              () => _selectedCategory = category,
                            );
                            if (category != 'All') {
                              // Convert display name back to API format (lowercase)
                              final apiCategory = category.toLowerCase();
                              debugPrint(
                                '📂 Category selected: $apiCategory',
                              );
                              // context.read<NewsProvider>().fetchCategoryNews(
                              //       apiCategory,
                              //       limit: 10,
                              //     );
                              _loadInitialCategoryNews(apiCategory);
                            } else {
                              // If "All" is selected, clear category filter
                              debugPrint(
                                '📂 All categories selected',
                              );
                              // context
                              //     .read<NewsProvider>()
                              //     .clearCategoryFilter();
                              _loadInitialTodayNews();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
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
                    );
                  },
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                key: const ValueKey('news_feed_refresh_indicator'),
                onRefresh: () async {
                  // Refresh breaking news + the active view for the selected date
                  await newsProvider.fetchBreakingNews();
                  if (!mounted) return;
                  if (_selectedCategory == 'All') {
                    await _loadInitialTodayNews(allowCacheFallback: false);
                  } else {
                    await _loadInitialCategoryNews(
                      _selectedCategory.toLowerCase(),
                      allowCacheFallback: false,
                    );
                  }
                },
                child: CustomScrollView(
                  key: const PageStorageKey('news_feed_scroll_view'),
                  controller: _scrollController,
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Required for RefreshIndicator
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
                          style: FontManager.headline3.copyWith(
                            color: const Color(0xFFE31E24),
                            fontSize: 24,
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
                          height: 220,
                          child: _buildBreakingNewsShimmer(theme),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: CarouselSlider.builder(
                          itemCount: newsProvider.breakingNews.isNotEmpty
                              ? newsProvider.breakingNews.length.clamp(
                                  0,
                                  10,
                                ) // Limit to 10 on home page
                              : widget.newsList.length.clamp(0, 10),
                          itemBuilder: (context, index, realIndex) {
                            final articles = newsProvider
                                    .breakingNews.isNotEmpty
                                ? newsProvider.breakingNews.take(10).toList()
                                : widget.newsList
                                    .take(10)
                                    .map((e) => _mapToArticle(e))
                                    .toList();
                            final article = articles[index];
                            return _buildBreakingNewsCard(
                              context,
                              article,
                              remoteConfig,
                              index,
                              articles,
                            );
                          },
                          options: CarouselOptions(
                            height:
                                220, // Reduced height for rectangular layout
                            viewportFraction:
                                0.90, // Increased for better visibility
                            initialPage: 0,
                            enableInfiniteScroll: false,
                            reverse: false,
                            autoPlay: false,
                            enlargeCenterPage:
                                false, // Disabled for rectangular cards
                            onPageChanged: (index, reason) {
                              // Optional: Handle page change
                            },
                            scrollDirection: Axis.horizontal,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Heading - Category name or Date heading
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: showHeadingText(
                          _selectedCategory != 'All'
                              ? _selectedCategory
                              : _getDateHeadingText(_selectedDate),
                          theme,
                        ),
                      ),
                    ),

                    // Category news or Today's news list items
                    if (_selectedCategory != 'All')
                      // Show category news when a category is selected
                      if (newsProvider.isLoadingCategoryNews &&
                          _allCategoryNews.isEmpty)
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
                      else if (_allCategoryNews.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                newsProvider.hasRegionFilter
                                    ? LocalizationHelper.noNewsForRegion(
                                        context)
                                    : (_selectedCategory == 'All'
                                        ? LocalizationHelper.noNewsForDate(
                                            context)
                                        : LocalizationHelper
                                            .noNewsForThisCategory(context)),
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
                                if (AdPlacementHelper.isAdSlot(index) &&
                                    AdPlacementHelper.shouldShowInlineAds(
                                      AdService().policy,
                                    )) {
                                  return InlineFeedAd(
                                    slotIndex:
                                        AdPlacementHelper.adSlotIndex(index),
                                  );
                                }

                                final articleIndex =
                                    AdPlacementHelper.shouldShowInlineAds(
                                  AdService().policy,
                                )
                                        ? AdPlacementHelper
                                            .articleIndexForListIndex(index)
                                        : index;

                                if (articleIndex >= _allCategoryNews.length) {
                                  return const SizedBox.shrink();
                                }

                                final article = _allCategoryNews[articleIndex];
                                return NewsGridView(
                                  key: ValueKey(
                                    'category_${article.articleId ?? articleIndex}',
                                  ),
                                  type: 'listview',
                                  newsDetails: article,
                                  onListenTapped: () async {
                                    try {
                                      final newsProvider =
                                          context.read<NewsProvider>();
                                      final categoryNews = _allCategoryNews;

                                      // Find the index of current article in category news
                                      final startIndex =
                                          categoryNews.indexWhere(
                                        (a) =>
                                            (a.articleId ?? a.title) ==
                                            (article.articleId ??
                                                article.title),
                                      );

                                      if (startIndex >= 0 &&
                                          startIndex < categoryNews.length) {
                                        // Set playlist with all category news and start from clicked article
                                        await context
                                            .read<AudioPlayerProvider>()
                                            .setPlaylistAndPlay(
                                              categoryNews,
                                              startIndex,
                                              playTitle: true,
                                              category: 'date',
                                            );
                                      } else {
                                        // Fallback: play single article
                                        await context
                                            .read<AudioPlayerProvider>()
                                            .playArticleFromUrl(
                                              article,
                                              playTitle: true,
                                              category: 'date',
                                            );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              LocalizationHelper
                                                  .errorPlayingAudio(
                                                      context, e.toString()),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  onSaveTapped: () async {
                                    try {
                                      final bookmarkProvider =
                                          context.read<BookmarkProvider>();
                                      final newStatus = await bookmarkProvider
                                          .toggleBookmark(article);

                                      // Update article status in NewsProvider lists
                                      final newsProvider =
                                          context.read<NewsProvider>();
                                      newsProvider.updateArticleBookmarkStatus(
                                        article,
                                        newStatus,
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              newStatus
                                                  ? LocalizationHelper
                                                      .addedToBookmarks(context)
                                                  : LocalizationHelper
                                                      .removedFromBookmarks(
                                                          context),
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              LocalizationHelper.error(
                                                  context, e.toString()),
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  onNewsTapped: () {
                                    NewsDetailScreen.open(
                                      context,
                                      article: article,
                                      articles: _allCategoryNews,
                                      initialIndex: articleIndex,
                                    );
                                  },
                                  onShareTapped: () {
                                    showNewsShareBottomSheet(context, article);
                                  },
                                );
                              },
                              childCount: () {
                                final capped =
                                    _allCategoryNews.length.clamp(0, 10);
                                if (AdPlacementHelper.shouldShowInlineAds(
                                  AdService().policy,
                                )) {
                                  return AdPlacementHelper.totalItemCount(
                                    capped,
                                  );
                                }
                                return capped;
                              }(),
                            ),
                          ),
                        )
                    else
                    // Show today's news when "All" is selected
                    if (newsProvider.isLoadingToday && _allTodayNews.isEmpty)
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
                    else if (_allTodayNews.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              _emptyFeedMessage(context, newsProvider),
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
                              final feedItems =
                                  AdPlacementHelper.shouldShowInlineAds(
                                AdService().policy,
                              )
                                      ? AdPlacementHelper.totalItemCount(
                                          _allTodayNews.length,
                                        )
                                      : _allTodayNews.length;

                              if (index >= feedItems) {
                                return _isLoadingMoreToday
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }

                              if (AdPlacementHelper.isAdSlot(index) &&
                                  AdPlacementHelper.shouldShowInlineAds(
                                    AdService().policy,
                                  )) {
                                return InlineFeedAd(
                                  slotIndex:
                                      AdPlacementHelper.adSlotIndex(index),
                                );
                              }

                              final articleIndex =
                                  AdPlacementHelper.shouldShowInlineAds(
                                AdService().policy,
                              )
                                      ? AdPlacementHelper
                                          .articleIndexForListIndex(index)
                                      : index;

                              if (articleIndex >= _allTodayNews.length) {
                                return const SizedBox.shrink();
                              }

                              final article = _allTodayNews[articleIndex];

                              return NewsGridView(
                                key: ValueKey(
                                  'today_${article.articleId ?? articleIndex}',
                                ),
                                type: 'listview',
                                newsDetails: article,
                                onListenTapped: () async {
                                  try {
                                    final startIndex = _allTodayNews.indexWhere(
                                      (a) =>
                                          (a.articleId ?? a.title) ==
                                          (article.articleId ?? article.title),
                                    );

                                    if (startIndex >= 0) {
                                      await context
                                          .read<AudioPlayerProvider>()
                                          .setPlaylistAndPlay(
                                            _allTodayNews,
                                            startIndex,
                                            playTitle: true,
                                            category: 'date',
                                          );
                                    }
                                  } catch (e) {}
                                },
                                onSaveTapped: () async {
                                  try {
                                    final bookmarkProvider =
                                        context.read<BookmarkProvider>();

                                    final newStatus = await bookmarkProvider
                                        .toggleBookmark(article);

                                    newsProvider.updateArticleBookmarkStatus(
                                      article,
                                      newStatus,
                                    );
                                  } catch (e) {}
                                },
                                onNewsTapped: () {
                                  NewsDetailScreen.open(
                                    context,
                                    article: article,
                                    articles: _allTodayNews,
                                    initialIndex: articleIndex,
                                  );
                                },
                                onShareTapped: () {
                                  showNewsShareBottomSheet(context, article);
                                },
                              );
                            },
                            childCount: (AdPlacementHelper.shouldShowInlineAds(
                                  AdService().policy,
                                )
                                    ? AdPlacementHelper.totalItemCount(
                                        _allTodayNews.length,
                                      )
                                    : _allTodayNews.length) +
                                (_isLoadingMoreToday ? 1 : 0),
                          ),
                        ),
                      ),
                    // Ad 2: Large Banner (320x100) - After today's news

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
                            final flashNews =
                                newsProvider.breakingNews.take(5).toList();
                            final data = flashNews[index];
                            return NewsGridView(
                              key: ValueKey('flash_$index'),
                              type: 'bannerview',
                              newsDetails: data,
                              onListenTapped: () async {
                                try {
                                  final newsProvider =
                                      context.read<NewsProvider>();
                                  final flashNews = newsProvider.breakingNews
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
                                          category: 'flash',
                                        );
                                  } else {
                                    // Fallback: play single article
                                    await context
                                        .read<AudioPlayerProvider>()
                                        .playArticleFromUrl(
                                          data,
                                          playTitle: true,
                                          category: 'flash',
                                        );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocalizationHelper.errorPlayingAudio(
                                              context, e.toString()),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              onSaveTapped: () async {
                                try {
                                  final bookmarkProvider =
                                      context.read<BookmarkProvider>();
                                  final newStatus = await bookmarkProvider
                                      .toggleBookmark(data);

                                  // Update article status in NewsProvider lists
                                  final newsProvider =
                                      context.read<NewsProvider>();
                                  newsProvider.updateArticleBookmarkStatus(
                                    data,
                                    newStatus,
                                  );

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          newStatus
                                              ? LocalizationHelper
                                                  .addedToBookmarks(context)
                                              : LocalizationHelper
                                                  .removedFromBookmarks(
                                                      context),
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
                              onNewsTapped: () {
                                NewsDetailScreen.open(
                                  context,
                                  article: data,
                                  articles: flashNews,
                                  initialIndex: index,
                                );
                              },
                              onShareTapped: () {
                                showNewsShareBottomSheet(context, data);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Live Cricket Score Section
                    // SliverToBoxAdapter(
                    //   child: Padding(
                    //     padding: const EdgeInsets.symmetric(horizontal: 16),
                    //     child: Column(
                    //       children: [
                    //         showHeadingText(
                    //           LocalizationHelper.liveCricketScore(context),
                    //           theme,
                    //         ),
                    //         const SizedBox(height: 12),
                    //         // card
                    //         Container(
                    //           margin: const EdgeInsets.only(top: 8),
                    //           padding: const EdgeInsets.all(16),
                    //           decoration: BoxDecoration(
                    //             color: Colors.white,
                    //             borderRadius: BorderRadius.circular(12),
                    //             boxShadow: [
                    //               BoxShadow(
                    //                 color: Colors.black.withOpacity(0.05),
                    //                 blurRadius: 10,
                    //                 offset: Offset(0, 2),
                    //               ),
                    //             ],
                    //           ),
                    //           child: Column(
                    //             children: [
                    //               Row(
                    //                 children: [
                    //                   Container(
                    //                     padding: const EdgeInsets.symmetric(
                    //                       horizontal: 8,
                    //                       vertical: 4,
                    //                     ),
                    //                     decoration: BoxDecoration(
                    //                       color: const Color(0xFFE31E24),
                    //                       borderRadius: BorderRadius.circular(
                    //                         4,
                    //                       ),
                    //                     ),
                    //                     child: const Text(
                    //                       'LIVE',
                    //                       style: TextStyle(
                    //                         color: Colors.white,
                    //                         fontSize: 10,
                    //                         fontWeight: FontWeight.bold,
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   const SizedBox(width: 8),
                    //                   const Text(
                    //                     'World T20 - T20 16 of 45',
                    //                     style: TextStyle(
                    //                       fontSize: 12,
                    //                       fontWeight: FontWeight.w600,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               const SizedBox(height: 16),
                    //               // India row
                    //               Row(
                    //                 children: [
                    //                   Container(
                    //                     width: 32,
                    //                     height: 24,
                    //                     decoration: BoxDecoration(
                    //                       borderRadius: BorderRadius.circular(
                    //                         4,
                    //                       ),
                    //                       color: Colors.orange,
                    //                     ),
                    //                     child: const Center(
                    //                       child: Text(
                    //                         '🇮🇳',
                    //                         style: TextStyle(fontSize: 16),
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   const SizedBox(width: 12),
                    //                   const Text(
                    //                     'IND',
                    //                     style: TextStyle(
                    //                       fontSize: 14,
                    //                       fontWeight: FontWeight.bold,
                    //                     ),
                    //                   ),
                    //                   const Spacer(),
                    //                   const Text(
                    //                     '172-8 (20)',
                    //                     style: TextStyle(
                    //                       fontSize: 14,
                    //                       fontWeight: FontWeight.bold,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               const SizedBox(height: 12),
                    //               // Pakistan row
                    //               Row(
                    //                 children: [
                    //                   Container(
                    //                     width: 32,
                    //                     height: 24,
                    //                     decoration: BoxDecoration(
                    //                       borderRadius: BorderRadius.circular(
                    //                         4,
                    //                       ),
                    //                       color: Colors.green,
                    //                     ),
                    //                     child: const Center(
                    //                       child: Text(
                    //                         '🇵🇰',
                    //                         style: TextStyle(fontSize: 16),
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   const SizedBox(width: 12),
                    //                   const Text(
                    //                     'PAK',
                    //                     style: TextStyle(
                    //                       fontSize: 14,
                    //                       fontWeight: FontWeight.bold,
                    //                     ),
                    //                   ),
                    //                   const Spacer(),
                    //                   const Text(
                    //                     '152/3 (15.4)',
                    //                     style: TextStyle(
                    //                       fontSize: 14,
                    //                       fontWeight: FontWeight.bold,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               const SizedBox(height: 16),
                    //               showMatchVS("AUS", "IND", remoteConfig),
                    //             ],
                    //           ),
                    //         ),
                    //         const SizedBox(
                    //           height: 24,
                    //         ), // bottom spacing for nav
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    // Ad 4: Large Banner (320x100) - At the end
                    // SliverToBoxAdapter(
                    //   child: BannerAdContainer(adSize: AdSize.largeBanner),
                    // ),
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
  Future<void> _refreshFeedFromFab() async {
    if (_isFabRefreshing || !mounted) return;

    setState(() => _isFabRefreshing = true);
    try {
      final newsProvider = context.read<NewsProvider>();
      await newsProvider.fetchBreakingNews();
      if (!mounted) return;

      if (_selectedCategory == 'All') {
        await _loadInitialTodayNews(allowCacheFallback: false);
      } else {
        await _loadInitialCategoryNews(
          _selectedCategory.toLowerCase(),
          allowCacheFallback: false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ FAB refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isFabRefreshing = false);
      }
    }
  }

  Widget _buildRefreshButton(
    BuildContext context,
    NewsProvider newsProvider,
    RemoteConfigModel remoteConfig,
  ) {
    final isRefreshing = _isFabRefreshing ||
        newsProvider.isLoading ||
        newsProvider.isLoadingToday ||
        newsProvider.isLoadingCategoryNews;

    return FloatingActionButton(
      heroTag: 'news_feed_refresh_fab',
      // Keep onPressed non-null so the FAB stays primary-colored while spinning
      // (null disables and greys out the white spinner).
      onPressed: isRefreshing ? () {} : _refreshFeedFromFab,
      backgroundColor: remoteConfig.primaryColorValue,
      foregroundColor: Colors.white,
      child: isRefreshing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh, color: Colors.white),
    );
  }

  /// Build breaking news card with responsive rectangular layout
  Widget _buildBreakingNewsCard(
    BuildContext context,
    NewsArticle article,
    RemoteConfigModel config,
    int articleIndex,
    List<NewsArticle> articles,
  ) {
    return GestureDetector(
      onTap: () {
        NewsDetailScreen.open(
          context,
          article: article,
          articles: articles,
          initialIndex: articleIndex,
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive dimensions based on screen size
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth >= 768;
          final isLargePhone = screenWidth >= 414;

          // Responsive sizing
          final cardHeight = isTablet ? 200.0 : (isLargePhone ? 180.0 : 160.0);
          final imageWidth = cardHeight * 1.05; // Maintain aspect ratio
          final horizontalPadding = screenWidth * 0.04; // 4% of screen width
          final contentPadding = cardHeight * 0.08; // 8% of card height

          return Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Image section
                  SizedBox(
                    width: imageWidth,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image
                        _buildCardImage(article),

                        // Gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content section
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(contentPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.98),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top section with label and bookmark
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE31E24)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    LocalizationHelper.hotNews(context),
                                    style: FontManager.subtitle2.copyWith(
                                      color: const Color(0xFFE31E24),
                                      fontSize: isTablet ? 14 : 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Bookmark icon
                              Consumer<BookmarkProvider>(
                                builder: (context, bookmarkProvider, child) {
                                  final isBookmarked =
                                      bookmarkProvider.isBookmarked(article);
                                  return GestureDetector(
                                    onTap: () async {
                                      try {
                                        final newStatus = await bookmarkProvider
                                            .toggleBookmark(article);

                                        // Update article status in NewsProvider lists
                                        final newsProvider =
                                            context.read<NewsProvider>();
                                        newsProvider
                                            .updateArticleBookmarkStatus(
                                          article,
                                          newStatus,
                                        );

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                newStatus
                                                    ? LocalizationHelper
                                                        .addedToBookmarks(
                                                            context)
                                                    : LocalizationHelper
                                                        .removedFromBookmarks(
                                                            context),
                                              ),
                                              duration:
                                                  const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  LocalizationHelper.error(
                                                      context, e.toString())),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isBookmarked
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: isBookmarked
                                            ? const Color(0xFFE31E24)
                                            : Colors.grey[600],
                                        size: isTablet ? 20 : 18,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          // Title section
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _buildTitleText(
                                article.title,
                                maxLines: isTablet ? 4 : 7,
                                fontSize: isTablet ? 16 : 14,
                              ),
                            ),
                          ),

                          // Bottom section with listen button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              showListenButton(
                                config,
                                () async {
                                  try {
                                    final newsProvider =
                                        context.read<NewsProvider>();
                                    final breakingNews =
                                        newsProvider.breakingNews.isNotEmpty
                                            ? newsProvider.breakingNews
                                            : widget.newsList
                                                .map((e) => _mapToArticle(e))
                                                .toList();

                                    // Find the index of current article in the list
                                    final startIndex = articleIndex ??
                                        breakingNews.indexWhere(
                                          (a) =>
                                              (a.articleId ?? a.title) ==
                                              (article.articleId ??
                                                  article.title),
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
                                            category: 'breaking',
                                          );
                                    } else {
                                      // Fallback: play single article
                                      await context
                                          .read<AudioPlayerProvider>()
                                          .playArticleFromUrl(
                                            article,
                                            playTitle: true,
                                            category: 'breaking',
                                          );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(LocalizationHelper
                                              .errorPlayingAudio(
                                                  context, e.toString())),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                context,
                                article,
                                true, // isCompact parameter
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build card image with proper handling
  Widget _buildCardImage(NewsArticle article) {
    return NewsArticleImage.fromArticle(
      article,
      fit: BoxFit.cover,
    );
  }

  /// Build title text with responsive styling for rectangular layout
  Widget _buildTitleText(
    String title, {
    int maxLines = 3,
    double fontSize = 14,
    Color textColor = Colors.black87,
  }) {
    return Text(
      title,
      style: GoogleFonts.roboto(
        fontSize: fontSize,
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
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
            width: MediaQuery.of(context).size.width / 2.5,
            height: MediaQuery.of(context).size.height / 5.5,
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
      final locale = Localizations.localeOf(context).toString();
      return DateFormat('dd MMM yyyy', locale).format(date);
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final l10n = AppLocalizations.of(context);
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.day,
          helpText: l10n.selectDate,
          cancelText: l10n.cancel,
          confirmText: l10n.datePickerConfirm,
          fieldLabelText: l10n.dateLabel,
          fieldHintText: l10n.datePickerFieldHint,
        );
        if (picked != null && picked != _selectedDate) {
          // Normalize the date to remove time components
          final normalizedDate =
              DateTime(picked.year, picked.month, picked.day);
          setState(() => _selectedDate = normalizedDate);
          // Fetch news for the selected date — keep the active category in sync
          if (mounted) {
            if (_selectedCategory == 'All') {
              await _loadInitialTodayNews(allowCacheFallback: false);
            } else {
              await _loadInitialCategoryNews(
                _selectedCategory.toLowerCase(),
                allowCacheFallback: false,
              );
            }
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
              DateFormat('dd MMM', Localizations.localeOf(context).toString())
                  .format(_selectedDate),
              style: FontManager.caption.copyWith(
                color: Colors.white,
                fontSize: 12,
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
