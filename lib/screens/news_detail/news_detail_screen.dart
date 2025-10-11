import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/news_article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/tts_provider.dart';
import '../../core/constants/app_constants.dart';

/// News detail screen - Full article view
class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const NewsDetailScreen({
    super.key,
    required this.article,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showTitle) {
      setState(() => _showTitle = true);
    } else if (_scrollController.offset <= 200 && _showTitle) {
      setState(() => _showTitle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final ttsProvider = Provider.of<TtsProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(widget.article);
    final isPlaying = ttsProvider.isArticlePlaying(widget.article);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar with image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            title: _showTitle
                ? Text(
                    widget.article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.article.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.article.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surface,
                            child: const Icon(Icons.image_not_supported, size: 48),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: const Icon(Icons.article, size: 48),
                    ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () {
                  bookmarkProvider.toggleBookmark(widget.article);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isBookmarked
                            ? AppConstants.bookmarkRemoved
                            : AppConstants.bookmarkAdded,
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  if (widget.article.link != null) {
                    Share.share(
                      '${widget.article.title}\n\n${widget.article.link}',
                      subject: widget.article.title,
                    );
                  }
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badges
                  if (widget.article.category != null &&
                      widget.article.category!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: widget.article.category!.map((cat) {
                        return Chip(
                          label: Text(
                            cat.toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: AppConstants.defaultPadding),

                  // Title
                  Text(
                    widget.article.title,
                    style: theme.textTheme.displaySmall,
                  ),

                  const SizedBox(height: AppConstants.defaultPadding),

                  // Metadata
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          widget.article.authorName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.authorName,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              '${widget.article.formattedDate} • ${widget.article.readingTime}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.largePadding),

                  // Play/Pause button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (isPlaying) {
                          ttsProvider.pause();
                        } else {
                          ttsProvider.playArticle(widget.article);
                        }
                      },
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(isPlaying ? 'Pause Audio' : 'Listen to Article'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.borderRadius),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.largePadding),

                  const Divider(),

                  const SizedBox(height: AppConstants.defaultPadding),

                  // Description
                  if (widget.article.description != null)
                    Text(
                      widget.article.description!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),

                  const SizedBox(height: AppConstants.defaultPadding),

                  // Content
                  if (widget.article.content != null)
                    Text(
                      widget.article.content!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                      ),
                    ),

                  const SizedBox(height: AppConstants.largePadding),

                  // Read full article button
                  if (widget.article.link != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(widget.article.link!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Read Full Article'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.borderRadius),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppConstants.largePadding),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
