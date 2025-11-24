import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';
import '../screens/audio_player/audio_player_screen.dart';

/// Spotify-like Mini Player Widget
/// Displays at the bottom of the screen when audio is playing
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        // Only show if there's a current article
        if (!audioProvider.hasCurrentArticle || audioProvider.currentArticle == null) {
          return const SizedBox.shrink();
        }

        final article = audioProvider.currentArticle!;

        return GestureDetector(
          onTap: () {
            // Navigate to full player screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AudioPlayerScreen(),
              ),
            );
          },
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Article thumbnail
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                    ),
                    child: article.imageUrl != null
                        ? Image.network(
                            article.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.article,
                                color: Colors.grey[600],
                                size: 30,
                              );
                            },
                          )
                        : Icon(
                            Icons.article,
                            color: Colors.grey[600],
                            size: 30,
                          ),
                  ),

                  // Article info and controls
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // Article title and source
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  article.sourceName ?? 'News',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Play/Pause button
                          IconButton(
                            icon: Icon(
                              audioProvider.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => audioProvider.togglePlayPause(),
                          ),

                          // Stop button
                          IconButton(
                            icon: const Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => audioProvider.stop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

