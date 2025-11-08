// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/screens/news_detail/news_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../core/widgets/language_selector_dialog.dart';
import '../../../widgets/news_grid_views.dart';
import '../../../data/models/news_article.dart';
import '../../../providers/tts_provider.dart';
import '../../../providers/bookmark_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

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

  final List<String> categories = [
    'All',
    'Politics',
    'Sports',
    'Education',
    'Business',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NewsProvider>().fetchBreakingNews();
      context.read<NewsProvider>().fetchNewsByCategory('top');
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _breakingNewsController.dispose();
    _flashNewsController.dispose();
    super.dispose();
  }

  showHeadingText(String text, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: GoogleFonts.playfair(
            color: theme.colorScheme.secondary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "View All",
          style: GoogleFonts.inter(
            color: Color(0xFFC70000),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  showSharModalBottomSheet() {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final remoteConfig = context.read<RemoteConfigProvider>().config;
    final newsProvider = context.watch<NewsProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header: logo + date + language
            SliverToBoxAdapter(
              child: Padding(
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
            ),

            // Section title - Breaking News
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Breaking News',
                  style: TextStyle(
                    color: Color(0xFFE31E24),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Breaking News PageView (as normal widget inside SliverToBoxAdapter)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _breakingNewsController,
                  itemCount:
                      newsProvider.breakingNews.isNotEmpty
                          ? newsProvider.breakingNews.length
                          : widget.newsList.length,
                  itemBuilder: (context, index) {
                    final article =
                        newsProvider.breakingNews.isNotEmpty
                            ? newsProvider.breakingNews[index]
                            : _mapToArticle(widget.newsList[index]);
                    // Use NewsGridView for the card display
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: NewsGridView(
                        key: ValueKey('breaking_$index'),
                        type: 'cardview',
                        newsDetails: _articleToMap(article),
                        onListenTapped: () {
                          // context.read<TtsProvider>().playArticle(article);
                        },
                        onSaveTapped: () {
                          // context.read<BookmarkProvider>().toggleBookmark(
                          //   article,
                          // );
                        },
                        onNewsTapped: () async {
                          NewsArticle newsArticle = await getNewsDetail();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      NewsDetailScreen(article: newsArticle!),
                            ),
                          );

                          // navigate to detail (if you have a detail screen)
                        },
                        onShareTapped: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (c) {
                              return showSharModalBottomSheet();
                            },
                          );
                        },
                      ),
                    );
                  },
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
                            context.read<NewsProvider>().fetchNewsByCategory(
                              category.toLowerCase(),
                            );
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

            // Today heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: showHeadingText("Today", theme),
              ),
            ),

            // Today list items
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data = widget.newsList[index];
                  return NewsGridView(
                    key: ValueKey('today_$index'),
                    type: 'listview',
                    newsDetails: data,
                    onListenTapped: () {},
                    onSaveTapped: () {},
                    onNewsTapped: () async {
                      NewsArticle newsArticle = await getNewsDetail();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  NewsDetailScreen(article: newsArticle!),
                        ),
                      );
                    },
                    onShareTapped: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (c) {
                          return showSharModalBottomSheet();
                        },
                      );
                    },
                  );
                }, childCount: widget.newsList.length),
              ),
            ),

            // Flash news section title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: showHeadingText("Flash News", theme),
              ),
            ),

            // Flash news PageView (no nested sliver)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _flashNewsController,
                  itemCount:
                      newsProvider.articles.isNotEmpty
                          ? newsProvider.articles.length
                          : widget.newsList.length,
                  itemBuilder: (context, index) {
                    final data = widget.newsList[index];
                    return NewsGridView(
                      key: ValueKey('today_$index'),
                      type: 'bannerview',
                      newsDetails: data,
                      onListenTapped: () {},
                      onSaveTapped: () {},
                      onNewsTapped: () async {
                        NewsArticle newsArticle = await getNewsDetail();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    NewsDetailScreen(article: newsArticle!),
                          ),
                        );
                      },
                      onShareTapped: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (c) {
                            return showSharModalBottomSheet();
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
                    showHeadingText("Live Cricket Score", theme),
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
                                  borderRadius: BorderRadius.circular(4),
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
                                  borderRadius: BorderRadius.circular(4),
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
                                  borderRadius: BorderRadius.circular(4),
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
                    const SizedBox(height: 24), // bottom spacing for nav
                  ],
                ),
              ),
            ),
          ],
        ),
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

  // Helper: convert NewsArticle to Map used by NewsGridView
  Map _articleToMap(NewsArticle a) {
    return {
      'img': a.imageUrl ?? '',
      'category':
          (a.category != null && a.category!.isNotEmpty)
              ? a.category!.first
              : '',
      'headLines': a.title ?? '',
      'updatedAt': '', // fill if available
      'link': a.link ?? '',
    };
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
