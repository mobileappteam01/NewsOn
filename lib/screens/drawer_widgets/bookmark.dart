import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../core/widgets/news_card.dart';
import '../news_detail/news_detail_screen.dart';

class BookMark extends StatefulWidget {
  const BookMark({super.key});

  @override
  State<BookMark> createState() => _BookMarkState();
}

class _BookMarkState extends State<BookMark> {
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
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final bookmarkProvider = Provider.of<BookmarkProvider>(context);

        final displayedBookmarks =
            _searchQuery.isEmpty
                ? bookmarkProvider.bookmarks
                : bookmarkProvider.searchBookmarks(_searchQuery);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          LocalizationHelper.bookmarks(context),
                          style: GoogleFonts.playfairDisplay(
                            color: config.primaryColorValue,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search bar
                if (bookmarkProvider.hasBookmarks)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: LocalizationHelper.search(context),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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

                const SizedBox(height: 16),

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
                                    bookmarkProvider.loadBookmarks(
                                      refresh: true,
                                    );
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
                              await bookmarkProvider.loadBookmarks(
                                refresh: true,
                              );
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
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
                                return NewsCard(
                                  article: article,
                                  onTap: () {
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
                                );
                              },
                            ),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
