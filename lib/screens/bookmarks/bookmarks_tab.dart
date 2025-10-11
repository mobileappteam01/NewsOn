import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/news_card.dart';
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
      context.read<BookmarkProvider>().loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);

    final displayedBookmarks = _searchQuery.isEmpty
        ? bookmarkProvider.bookmarks
        : bookmarkProvider.searchBookmarks(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
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
      body: Column(
        children: [
          // Search bar
          if (bookmarkProvider.hasBookmarks)
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search bookmarks...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
            child: bookmarkProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !bookmarkProvider.hasBookmarks
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: 64,
                              color: theme.colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bookmarks yet',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Save articles to read them later',
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
                                  'No results found',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayedBookmarks.length,
                            itemBuilder: (context, index) {
                              final article = displayedBookmarks[index];
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
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(
      BuildContext context, BookmarkProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text(
          'This will remove all saved articles. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAllBookmarks();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All bookmarks cleared'),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
