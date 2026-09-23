import 'package:flutter/material.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../domain/audio_state.dart';
import '../audio_controller.dart';

/// Compact bottom bar for active V2 playback (detail screen).
class V2AudioPlayerBar extends StatelessWidget {
  const V2AudioPlayerBar({
    super.key,
    required this.controller,
  });

  final V2AudioController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.state;
        if (s.articleId == null) return const SizedBox.shrink();
        if (s.phase != V2AudioUiPhase.playing &&
            s.phase != V2AudioUiPhase.paused &&
            s.phase != V2AudioUiPhase.preparing &&
            s.phase != V2AudioUiPhase.ready) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final total = s.duration.inMilliseconds <= 0
            ? 1.0
            : s.duration.inMilliseconds.toDouble();
        final pos = s.position.inMilliseconds
            .clamp(0, s.duration.inMilliseconds)
            .toDouble();

        return Material(
          elevation: 2,
          color: theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.phase == V2AudioUiPhase.preparing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(LocalizationHelper.v2AudioPreparing(context)),
                    )
                  else ...[
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: s.phase == V2AudioUiPhase.playing
                              ? LocalizationHelper.v2AudioPause(context)
                              : LocalizationHelper.v2AudioResume(context),
                          child: IconButton(
                            icon: Icon(
                              s.phase == V2AudioUiPhase.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () {
                              if (s.phase == V2AudioUiPhase.playing) {
                                controller.pause();
                              } else {
                                controller.resume();
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            slider: true,
                            label: LocalizationHelper.v2AudioSeek(context),
                            child: Slider(
                              value: pos,
                              max: total,
                              onChanged: (v) {
                                controller.seek(
                                  Duration(milliseconds: v.round()),
                                );
                              },
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: LocalizationHelper.v2AudioClose(context),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: controller.stopAndClear,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
