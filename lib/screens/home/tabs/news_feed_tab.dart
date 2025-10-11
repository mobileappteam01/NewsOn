import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/tts_provider.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/breaking_news_card.dart';
import '../../../core/widgets/news_card.dart';
import '../../news_detail/news_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

/// News feed tab - Main content tab matching exact UI
class NewsFeedTab extends StatefulWidget {
  final List<String> selectedCategories;

  const NewsFeedTab({
    super.key,
    required this.selectedCategories,
  });

  @override
  State<NewsFeedTab> createState() => _NewsFeedTabState();
}

class _NewsFeedTabState extends State<NewsFeedTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'All';
  final PageController _breakingNewsController = PageController();
  final PageController _flashNewsController = PageController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NewsProvider>().loadMoreNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final newsProvider = Provider.of<NewsProvider>(context);
    final ttsProvider = Provider.of<TtsProvider>(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NEWS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text('ON'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await newsProvider.refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Breaking News Section
            if (newsProvider.breakingNews.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Row(
                        children: [
                          Text(
                            'Breaking News',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 8,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        padEnds: false,
                        itemCount: newsProvider.breakingNews.take(5).length,
                        itemBuilder: (context, index) {
                          final article = newsProvider.breakingNews[index];
                          return BreakingNewsCard(
                            article: article,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      NewsDetailScreen(article: article),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppConstants.largePadding),
                  ],
                ),
              ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    child: Text(
                      "Today's News",
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultPadding),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      itemCount: widget.selectedCategories.length,
                      itemBuilder: (context, index) {
                        final category = widget.selectedCategories[index];
                        final isSelected = _selectedCategory == category;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                              newsProvider.fetchNewsByCategory(category);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.brightness == Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  category.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultPadding),
                ],
              ),
            ),

            // News List
            if (newsProvider.isLoading && newsProvider.articles.isEmpty)
              const SliverFillRemaining(
                child: LoadingShimmer(),
              )
            else if (newsProvider.error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        newsProvider.error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          newsProvider.refresh();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (newsProvider.articles.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No news available'),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < newsProvider.articles.length) {
                      final article = newsProvider.articles[index];
                      return NewsCard(
                        article: article,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  NewsDetailScreen(article: article),
                            ),
                          );
                        },
                      );
                    } else if (newsProvider.isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return null;
                  },
                  childCount: newsProvider.articles.length +
                      (newsProvider.isLoadingMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
