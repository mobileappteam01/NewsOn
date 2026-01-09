// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/widgets/news_card.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../../providers/news_provider.dart';
import '../../widgets/news_grid_views.dart';
import '../home/tabs/news_feed_tab_new.dart';
import '../news_detail/news_detail_screen.dart';

/// Bookmarks tab - View saved articles
class BookmarksTab extends StatefulWidget {
  const BookmarksTab({super.key});

  @override
  State<BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends State<BookmarksTab>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().loadBookmarks(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);

    final displayedBookmarks =
        _searchQuery.isEmpty
            ? bookmarkProvider.bookmarks
            : bookmarkProvider.searchBookmarks(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationHelper.bookmarks(context)),
        actions: [
          if (bookmarkProvider.hasBookmarks)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _showClearConfirmation(context, bookmarkProvider);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              if (bookmarkProvider.hasBookmarks)
                Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: LocalizationHelper.search(context),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

              // Bookmarks count
              if (bookmarkProvider.hasBookmarks)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${displayedBookmarks.length} bookmark${displayedBookmarks.length != 1 ? 's' : ''}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppConstants.defaultPadding),

              // Bookmarks list
              Expanded(
                child:
                    bookmarkProvider.isLoading &&
                            bookmarkProvider.bookmarks.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : bookmarkProvider.error != null &&
                            bookmarkProvider.bookmarks.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading bookmarks',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bookmarkProvider.error ?? 'Unknown error',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  bookmarkProvider.loadBookmarks(refresh: true);
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                        : !bookmarkProvider.hasBookmarks
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                size: 64,
                                color: theme.primaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Bookmarks',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Articles you bookmark will appear here',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                        : displayedBookmarks.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                LocalizationHelper.noResultsFound(context),
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: () async {
                            await bookmarkProvider.loadBookmarks(refresh: true);
                          },
                          child: ListView.builder(
                            itemCount:
                                displayedBookmarks.length +
                                (bookmarkProvider.hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayedBookmarks.length) {
                                // Load more indicator
                                if (bookmarkProvider.hasMore) {
                                  bookmarkProvider.loadMoreBookmarks();
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                              final article = displayedBookmarks[index];
                              // return NewsCard(
                              //   article: article,
                              //   onTap: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder:
                              //             (context) => NewsDetailScreen(
                              //               article: article,
                              //             ),
                              //       ),
                              //     );
                              //   },
                              // );
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
                                                ? 'Added to bookmarks'
                                                : 'Removed from bookmarks',
                                          ),
                                          duration: const Duration(seconds: 1),
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
                                            'Error: ${e.toString()}',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
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
                          ),
                        ),
              ),
            ],
          ),
          // Audio Mini Player (Spotify-like)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const AudioMiniPlayer(),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, BookmarkProvider provider) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(LocalizationHelper.clearAllBookmarks(context)),
            content: const Text(
              'This will remove all saved articles. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocalizationHelper.cancel(context)),
              ),
              TextButton(
                onPressed: () {
                  provider.clearAllBookmarks();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All bookmarks cleared')),
                  );
                },
                child: Text(LocalizationHelper.clear(context)),
              ),
            ],
          ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
