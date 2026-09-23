import 'package:flutter/material.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../domain/audio_state.dart';
import '../audio_controller.dart';

/// Optional bottom sheet for richer controls — keep lightweight.
Future<void> showV2AudioPlayerSheet({
  required BuildContext context,
  required V2AudioController controller,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final s = controller.state;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (s.phase == V2AudioUiPhase.preparing)
                  Text(LocalizationHelper.v2AudioPreparing(context))
                else if (s.phase == V2AudioUiPhase.failed)
                  Text(LocalizationHelper.v2AudioFailed(context))
                else if (s.phase == V2AudioUiPhase.unavailable)
                  Text(LocalizationHelper.v2AudioUnavailable(context))
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 40,
                        onPressed: s.phase == V2AudioUiPhase.playing
                            ? controller.pause
                            : controller.resume,
                        icon: Icon(
                          s.phase == V2AudioUiPhase.playing
                              ? Icons.pause_circle
                              : Icons.play_circle,
                        ),
                      ),
                    ],
                  ),
                TextButton(
                  onPressed: () {
                    controller.stopAndClear();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(LocalizationHelper.v2AudioClose(context)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
