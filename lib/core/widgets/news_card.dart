import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../data/models/news_article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/news_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/localization_helper.dart';

/// Reusable news card widget
class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final bool showImage;
  final bool showPlayButton;

  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.showImage = true,
    this.showPlayButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final audioProvider = Provider.of<AudioPlayerProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(article);
    final isPlaying = audioProvider.isArticlePlaying(article);

    return Container(
      margin: const EdgeInsets.only(
        left: AppConstants.defaultPadding,
        right: AppConstants.defaultPadding,
        bottom: AppConstants.defaultPadding,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (left side, smaller)
            if (showImage && article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        height: 100,
                        width: 100,
                        color: theme.colorScheme.surface,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 100,
                        width: 100,
                        color: theme.colorScheme.surface,
                        child: const Icon(Icons.image_not_supported, size: 32),
                      ),
                ),
              ),

            const SizedBox(width: 12),

            // Content section (right side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Metadata row
                  Row(
                    children: [
                      // Source
                      Expanded(
                        child: Text(
                          article.creator != null && article.creator!.isNotEmpty
                              ? article.creator![0]
                              : article.sourceName ??
                                  LocalizationHelper.unknownSource(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Listen button with red background
                      if (showPlayButton)
                        GestureDetector(
                          onTap: () async {
                            try {
                              if (isPlaying) {
                                await audioProvider.pause();
                              } else {
                                // Play single article
                                await audioProvider.playArticleFromUrl(
                                  article,
                                  playTitle: true,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error playing audio: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  LocalizationHelper.listen(context),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(width: 4),

                      // Bookmark icon - synced with BookmarkProvider
                      InkWell(
                        onTap: () async {
                          try {
                            final newBookmarkStatus = await bookmarkProvider
                                .toggleBookmark(article);

                            // Update article status in NewsProvider lists
                            final newsProvider = Provider.of<NewsProvider>(
                              context,
                              listen: false,
                            );
                            newsProvider.updateArticleBookmarkStatus(
                              article,
                              newBookmarkStatus,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newBookmarkStatus
                                        ? LocalizationHelper.addedToBookmarks(
                                          context,
                                        )
                                        : LocalizationHelper.removedFromBookmarks(
                                          context,
                                        ),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                            color:
                                isBookmarked
                                    ? (theme.brightness == Brightness.dark
                                        ? theme.primaryColor
                                        : const Color(
                                          0xFFE31E24,
                                        )) // Red when bookmarked
                                    : (theme.brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors
                                            .grey[600]), // Grey when not bookmarked
                          ),
                        ),
                      ),

                      // Share icon
                      InkWell(
                        onTap: () {
                          // Share functionality
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.share_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
