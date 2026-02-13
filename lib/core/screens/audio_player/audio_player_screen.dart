import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/remote_config_provider.dart';

/// Full Audio Player Screen - Spotify-like UI
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  bool _isDragging = false;
  Duration _dragPosition = Duration.zero;

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenImageView(
          imageUrl: imageUrl,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to AudioPlayerProvider changes
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        final configProvider = Provider.of<RemoteConfigProvider>(context);
        final config = configProvider.config;

        if (audioProvider.currentArticle == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: Text(
                'No audio playing',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final article = audioProvider.currentArticle!;
        final position = _isDragging ? _dragPosition : audioProvider.position;
        final duration = audioProvider.duration;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        'Now Playing',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // IconButton(
                      //   icon: const Icon(Icons.more_vert, color: Colors.white),
                      //   onPressed: () {
                      //     // Show options menu
                      //   },
                      // ),
                    ],
                  ),
                ),

                // Album Art / Article Image - Improved Responsive Rendering
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            // color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                // Main image with improved rendering
                                GestureDetector(
                                  onTap: () {
                                    if (article.imageUrl != null) {
                                      _showFullScreenImage(
                                          context, article.imageUrl!);
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    child: article.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: article.imageUrl!,
                                            fit: BoxFit
                                                .contain, // Preserve aspect ratio, show full image
                                            width: double.infinity,
                                            height: double.infinity,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: Colors.grey[900],
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Loading image...',
                                                      style: GoogleFonts.inter(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: Colors.grey[900],
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey[600],
                                                      size: 64,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Image not available',
                                                      style: GoogleFonts.inter(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: double.infinity,
                                            height: double.infinity,
                                            color: Colors.grey[900],
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.article,
                                                    color: Colors.grey[600],
                                                    size: 64,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'No image available',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.grey[600],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                // Visual indicator for full screen viewing
                                // if (article.imageUrl != null)
                                  // Positioned(
                                  //   top: 12,
                                  //   right: 12,
                                  //   child: Container(
                                  //     padding: const EdgeInsets.all(8),
                                  //     decoration: BoxDecoration(
                                  //       color: Colors.black.withOpacity(0.5),
                                  //       borderRadius: BorderRadius.circular(20),
                                  //     ),
                                  //     child: Icon(
                                  //       Icons.fullscreen,
                                  //       color: Colors.white,
                                  //       size: 20,
                                  //     ),
                                  //   ),
                                  // ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Article Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        article.title,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.sourceName ?? 'News',
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress Bar
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              activeTrackColor: config.primaryColorValue,
                              inactiveTrackColor: Colors.grey[800],
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: () {
                                final maxValue = duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 100.0;
                                final currentValue = duration.inMilliseconds > 0
                                    ? position.inMilliseconds.toDouble()
                                    : 0.0;
                                // Clamp value to ensure it's within bounds
                                return currentValue.clamp(0.0, maxValue);
                              }(),
                              max: duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 100.0,
                              min: 0.0,
                              onChanged: (value) {
                                setState(() {
                                  _isDragging = true;
                                  final maxMs = duration.inMilliseconds > 0
                                      ? duration.inMilliseconds
                                      : 100;
                                  _dragPosition = Duration(
                                    milliseconds: value.toInt().clamp(0, maxMs),
                                  );
                                });
                              },
                              onChangeEnd: (value) {
                                setState(() {
                                  _isDragging = false;
                                });
                                final maxMs = duration.inMilliseconds > 0
                                    ? duration.inMilliseconds
                                    : 100;
                                audioProvider.seek(
                                  Duration(
                                    milliseconds: value.toInt().clamp(0, maxMs),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  audioProvider.formatDuration(position),
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  audioProvider.formatDuration(duration),
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Speed control
                          IconButton(
                            icon: Text(
                              '${audioProvider.playbackSpeed}x',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _showSpeedDialog(context, audioProvider);
                            },
                          ),
                          const SizedBox(width: 8),

                          // Previous (skip back 10 seconds)
                          IconButton(
                            icon: const Icon(
                              Icons.replay_10,
                              color: Colors.white,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final newPosition =
                                  position - const Duration(seconds: 10);
                              final clampedPosition =
                                  newPosition < Duration.zero
                                      ? Duration.zero
                                      : (duration > Duration.zero &&
                                              newPosition > duration
                                          ? duration
                                          : newPosition);
                              audioProvider.seek(clampedPosition);
                            },
                          ),
                          const SizedBox(width: 4),

                          // Play/Pause
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: config.primaryColorValue,
                            ),
                            child: IconButton(
                              icon: Icon(
                                audioProvider.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                              iconSize: 36,
                              padding: const EdgeInsets.all(12),
                              onPressed: () => audioProvider.togglePlayPause(),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Background Music Indicator
                          if (audioProvider.isBackgroundMusicPlaying)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.music_note,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BG Music',
                                    style: GoogleFonts.inter(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Next (skip forward 10 seconds)
                          IconButton(
                            icon: const Icon(
                              Icons.forward_10,
                              color: Colors.white,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final newPosition =
                                  position + const Duration(seconds: 10);
                              final clampedPosition =
                                  newPosition < Duration.zero
                                      ? Duration.zero
                                      : (duration > Duration.zero &&
                                              newPosition > duration
                                          ? duration
                                          : newPosition);
                              audioProvider.seek(clampedPosition);
                            },
                          ),
                          const SizedBox(width: 8),

                          // Volume control
                          IconButton(
                            icon: Icon(
                              audioProvider.volume > 0.5
                                  ? Icons.volume_up
                                  : audioProvider.volume > 0
                                      ? Icons.volume_down
                                      : Icons.volume_off,
                              color: Colors.white,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _showVolumeDialog(context, audioProvider);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Additional controls
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     IconButton(
                      //       icon: const Icon(Icons.share, color: Colors.white),
                      //       onPressed: () {
                      //         // Share functionality
                      //       },
                      //     ),
                      //     IconButton(
                      //       icon: const Icon(
                      //         Icons.bookmark_border,
                      //         color: Colors.white,
                      //       ),
                      //       onPressed: () {
                      //         // Bookmark functionality
                      //       },
                      //     ),
                      //     IconButton(
                      //       icon: const Icon(Icons.stop, color: Colors.white),
                      //       onPressed: () {
                      //         audioProvider.stop();
                      //         Navigator.pop(context);
                      //       },
                      //     ),
                      //   ],
                      // ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpeedDialog(BuildContext context, AudioPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Playback Speed',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ...([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
              final isSelected = provider.playbackSpeed == speed;
              return ListTile(
                title: Text(
                  '${speed}x',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () {
                  provider.setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              );
            })),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showVolumeDialog(BuildContext context, AudioPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Volume Controls',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Speech Volume
            Text(
              'Speech Volume',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: provider.volume,
              onChanged: (value) {
                provider.setVolume(value);
              },
              activeColor: Colors.white,
              inactiveColor: Colors.grey[700],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.volume_mute, color: Colors.grey[400]),
                Text(
                  '${(provider.volume * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.volume_up, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 24),

            // Background Music Volume
            Text(
              'Background Music',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: provider.backgroundMusicVolume,
              onChanged: (value) {
                provider.setBackgroundMusicVolume(value);
              },
              activeColor: Colors.green,
              inactiveColor: Colors.grey[700],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.music_note, color: Colors.grey[400]),
                Text(
                  '${(provider.backgroundMusicVolume * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.music_note, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),

            // Background music status indicator
            Row(
              children: [
                Icon(
                  provider.isBackgroundMusicPlaying
                      ? Icons.music_note
                      : Icons.music_off,
                  color: provider.isBackgroundMusicPlaying
                      ? Colors.green
                      : Colors.grey[400],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  provider.isBackgroundMusicPlaying
                      ? 'Background music playing'
                      : 'Background music stopped',
                  style: GoogleFonts.inter(
                    color: provider.isBackgroundMusicPlaying
                        ? Colors.green
                        : Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full Screen Image Viewer Widget
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full screen image
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading image...',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Image not available',
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            // Image info hint
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pinch to zoom • Tap to close',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
