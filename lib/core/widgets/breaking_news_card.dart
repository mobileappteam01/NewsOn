import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../data/models/news_article.dart';
import '../../providers/tts_provider.dart';
import '../../core/constants/app_constants.dart';

/// Breaking news card with large image and play button overlay
class BreakingNewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const BreakingNewsCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ttsProvider = Provider.of<TtsProvider>(context);
    final isPlaying = ttsProvider.isArticlePlaying(article);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
        ),
        height: 280,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (article.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: theme.colorScheme.surface,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: theme.colorScheme.surface,
                        child: const Icon(Icons.image_not_supported, size: 48),
                      ),
                )
              else
                Container(
                  color: theme.colorScheme.surface,
                  child: const Icon(Icons.article, size: 48),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category badges
                      if (article.category != null &&
                          article.category!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            article.category!.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      const SizedBox(height: AppConstants.smallPadding),

                      // Title
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: AppConstants.smallPadding),

                      // Metadata
                      Row(
                        children: [
                          Text(
                            article.creator![0],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            article.pubDate!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        ttsProvider.pause();
                      } else {
                        ttsProvider.playArticle(article);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
