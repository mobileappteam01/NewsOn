import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'news_article_image.dart';
import '../../data/models/news_article.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/completed_news_provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/localization_helper.dart';

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
    final audioProvider = Provider.of<AudioPlayerProvider>(context);
    final completedProvider = Provider.of<CompletedNewsProvider>(context);
    final isPlaying = audioProvider.isArticlePlaying(article);
    final newsId = article.articleId ?? article.title;
    final isCompleted = completedProvider.isCompleted(newsId);
    final voiceEnabled =
        context.watch<RemoteConfigProvider>().isVoiceFeaturesEnabled;

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
              NewsArticleImage.fromArticle(
                article,
                fit: BoxFit.cover,
                backgroundColor: theme.colorScheme.surface,
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
                            color: theme.primaryColor,
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
                          Expanded(
                            child: Text(
                              '${LocalizationHelper.sourceLabel(context, article.sourceName ?? 'NewsOn')}${(article.creator != null && article.creator!.isNotEmpty) ? ' | ${LocalizationHelper.authorLabel(context, article.creator![0])}' : ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LocalizationHelper.publishedLabel(context, article.pubDate != null ? DateFormatter.formatDate(DateFormatter.parseApiDate(article.pubDate) ?? DateTime.now()) : DateFormatter.formatDate(DateTime.now())),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Play button overlay
              if (voiceEnabled)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF2E7D32)
                        : theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () async {
                      if (isPlaying) {
                        await audioProvider.pause();
                      } else {
                        try {
                          await audioProvider.playArticleFromUrl(
                            article,
                            playTitle: true,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    LocalizationHelper.errorPlayingAudio(
                                        context, e.toString())),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
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
