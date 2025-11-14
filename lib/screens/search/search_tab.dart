import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/news_card.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../data/models/remote_config_model.dart';
import '../../providers/remote_config_provider.dart';
import '../../widgets/news_grid_views.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../news_detail/news_detail_screen.dart';

/// Search tab - Search for news articles
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _recentSearches = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Listen to scroll for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.hasNextPage && !newsProvider.isLoadingMore) {
        newsProvider.loadMoreNews();
      }
    }
  }

  void _performSearch(String query, {bool immediate = false}) {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      context.read<NewsProvider>().clearSearch();
      return;
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (immediate) {
      _executeSearch(trimmedQuery);
    } else {
      // Debounce search - wait 500ms after user stops typing
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _executeSearch(trimmedQuery);
      });
    }
  }

  void _executeSearch(String query) {
    // Add to recent searches
    if (!_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      });
    }

    // Perform search
    context.read<NewsProvider>().searchNews(query, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final newsProvider = context.watch<NewsProvider>();
    final remoteConfig = context.read<RemoteConfigProvider>().config;

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), elevation: 0),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search news...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<NewsProvider>().clearSearch();
                            setState(() {});
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) => _performSearch(value, immediate: true),
              onChanged: (value) {
                setState(() {});
                if (value.trim().isNotEmpty) {
                  _performSearch(value);
                } else {
                  context.read<NewsProvider>().clearSearch();
                }
              },
            ),
          ),

          // Content area
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (newsProvider.currentQuery != null) {
                  await newsProvider.searchNews(
                    newsProvider.currentQuery!,
                    refresh: true,
                  );
                }
              },
              child:
                  newsProvider.currentQuery == null
                      ? _buildRecentSearches(theme, remoteConfig)
                      : newsProvider.isLoading && newsProvider.articles.isEmpty
                      ? const LoadingShimmer()
                      : newsProvider.error != null
                      ? _buildError(theme, newsProvider, remoteConfig)
                      : newsProvider.articles.isEmpty
                      ? _buildNoResults(theme, remoteConfig)
                      : _buildSearchResults(newsProvider, theme, remoteConfig),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(ThemeData theme, RemoteConfigModel config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: config.primaryColorValue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                final query = _recentSearches[index];
                return ListTile(
                  leading: Icon(Icons.history, color: config.primaryColorValue),
                  title: Text(query),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _recentSearches.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query, immediate: true);
                  },
                );
              },
            ),
          ),
        ] else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text('Search for news', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter keywords to find articles',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildError(
    ThemeData theme,
    NewsProvider newsProvider,
    RemoteConfigModel config,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              newsProvider.error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (newsProvider.currentQuery != null) {
                  newsProvider.searchNews(
                    newsProvider.currentQuery!,
                    refresh: true,
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColorValue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme, RemoteConfigModel config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    NewsProvider newsProvider,
    ThemeData theme,
    RemoteConfigModel config,
  ) {
    return Column(
      children: [
        // Results header with count
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${newsProvider.articles.length} ${newsProvider.articles.length == 1 ? 'result' : 'results'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (newsProvider.currentQuery != null)
                Text(
                  'Search: "${newsProvider.currentQuery}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: config.primaryColorValue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount:
                newsProvider.articles.length +
                (newsProvider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the end when loading more
              if (index == newsProvider.articles.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final article = newsProvider.articles[index];
              return NewsGridView(
                key: ValueKey('today_${article.articleId ?? index}'),
                type: 'listview',
                newsDetails: article,
                onListenTapped: () {
                  // context.read<TtsProvider>().playArticle(article);
                },
                onSaveTapped: () {
                  context.read<NewsProvider>().toggleBookmark(article);
                },
                onNewsTapped: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetailScreen(article: article),
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
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
