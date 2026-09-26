import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/routing/v2_routes.dart';
import '../../core/config/v2_feature_flags.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/widgets/news_card.dart';
import '../../core/widgets/news_share_bottom_sheet.dart';
import '../../features/bookmarks/presentation/v2_bookmark_list_tile.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/remote_config_provider.dart';
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
      if (!mounted) return;
      context.read<BookmarkProvider>().loadBookmarks(
            refresh: true,
            v2List: _v2Bookmarks(context),
          );
    });
  }

  bool _v2Bookmarks(BuildContext context) {
    final config = context.read<RemoteConfigProvider>().config;
    return V2FeatureFlags.homeReader(config) ||
        V2FeatureFlags.newArticleDetail(config);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final bookmarkProvider = Provider.of<BookmarkProvider>(context);
        final useV2 = _v2Bookmarks(context);

        // Copy so ListView is not tied to the provider's mutable list.
        final source = _searchQuery.isEmpty
            ? bookmarkProvider.bookmarks
            : bookmarkProvider.searchBookmarks(_searchQuery);
        final displayedBookmarks = List.of(source);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
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
                Expanded(
                  child: bookmarkProvider.isLoading &&
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
                                    LocalizationHelper.errorLoadingBookmarks(
                                        context),
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    bookmarkProvider.error ??
                                        LocalizationHelper.unknownError(
                                            context),
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      bookmarkProvider.loadBookmarks(
                                        refresh: true,
                                        v2List: useV2,
                                      );
                                    },
                                    child:
                                        Text(LocalizationHelper.retry(context)),
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
                                        color:
                                            theme.primaryColor.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        LocalizationHelper.noBookmarks(context),
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        LocalizationHelper
                                            .bookmarksWillAppearHere(context),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                )
                              : displayedBookmarks.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.search_off,
                                              size: 64),
                                          const SizedBox(height: 16),
                                          Text(
                                            LocalizationHelper.noResultsFound(
                                                context),
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ],
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        await bookmarkProvider.loadBookmarks(
                                          refresh: true,
                                          forceNetwork: true,
                                          v2List: useV2,
                                        );
                                      },
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        itemCount: displayedBookmarks.length +
                                            (bookmarkProvider.hasMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index ==
                                              displayedBookmarks.length) {
                                            if (bookmarkProvider.hasMore) {
                                              bookmarkProvider
                                                  .loadMoreBookmarks();
                                              return const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          }
                                          final article =
                                              displayedBookmarks[index];
                                          if (useV2) {
                                            return V2BookmarkListTile(
                                              key: ValueKey(
                                                'sidebar_v2_bookmark_'
                                                '${article.newsId ?? article.articleId ?? index}',
                                              ),
                                              article: article,
                                              bookmarked: bookmarkProvider
                                                  .isBookmarked(article),
                                              onOpen: () {
                                                V2Routes.openArticle(
                                                  context,
                                                  article: article,
                                                  articles: displayedBookmarks,
                                                  initialIndex: index,
                                                );
                                              },
                                              onBookmark: () async {
                                                try {
                                                  final nowBookmarked =
                                                      await bookmarkProvider
                                                          .toggleBookmarkV2(
                                                              article);
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        nowBookmarked
                                                            ? LocalizationHelper
                                                                .addedToBookmarks(
                                                                    context)
                                                            : LocalizationHelper
                                                                .removedFromBookmarks(
                                                                    context),
                                                      ),
                                                      duration: const Duration(
                                                          seconds: 1),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        LocalizationHelper
                                                            .error(
                                                          context,
                                                          e.toString(),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              onShare: () {
                                                showNewsShareBottomSheet(
                                                  context,
                                                  article,
                                                );
                                              },
                                            );
                                          }
                                          return NewsCard(
                                            article: article,
                                            onTap: () {
                                              NewsDetailScreen.open(
                                                context,
                                                article: article,
                                                articles: displayedBookmarks,
                                                initialIndex: index,
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
