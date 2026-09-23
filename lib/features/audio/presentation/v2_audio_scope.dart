import 'package:flutter/material.dart';

import '../data/v2_audio_playback_service.dart';
import 'audio_controller.dart';

/// Provides a shared [V2AudioController] for the subtree (single active stream).
class V2AudioScope extends InheritedNotifier<V2AudioController> {
  const V2AudioScope({
    super.key,
    required V2AudioController controller,
    required super.child,
  }) : super(notifier: controller);

  static V2AudioController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<V2AudioScope>();
    assert(scope != null, 'V2AudioScope not found');
    return scope!.notifier!;
  }

  static V2AudioController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<V2AudioScope>()
        ?.notifier;
  }
}

/// App-level holder so detail + feed share one player without Provider churn.
class V2AudioControllerHolder {
  V2AudioControllerHolder._();
  static final V2AudioPlaybackService playback = V2AudioPlaybackService();
  static V2AudioController? _controller;

  static V2AudioController obtain() {
    return _controller ??= V2AudioController(playback: playback);
  }
}
