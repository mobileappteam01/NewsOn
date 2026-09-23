import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/config/v2_feature_flags.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/news_article.dart';
import '../../../../providers/language_provider.dart';
import '../../../../providers/remote_config_provider.dart';
import '../../../news/domain/news_summary.dart';
import '../../domain/audio_state.dart';
import '../v2_audio_scope.dart';

/// Compact Listen control for detail / cut surfaces.
class V2AudioButton extends StatelessWidget {
  const V2AudioButton({
    super.key,
    required this.article,
    this.compact = false,
  });

  final NewsArticle article;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final RemoteConfigProvider remote;
    try {
      remote = Provider.of<RemoteConfigProvider>(context, listen: true);
    } on ProviderNotFoundException {
      // Widget tests / V1 trees without RemoteConfig — hide V2 audio.
      return const SizedBox.shrink();
    }
    final config = remote.config;
    if (!V2FeatureFlags.audio(config)) {
      return const SizedBox.shrink();
    }

    final controller =
        V2AudioScope.maybeOf(context) ?? V2AudioControllerHolder.obtain();
    final language = context.read<LanguageProvider>().newsLanguageCode;
    final generationEnabled = V2FeatureFlags.audioGeneration(config);
    final id = article.analyticsNewsId;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final isThis = state.articleId == id;

        if (isThis && state.phase == V2AudioUiPhase.preparing) {
          return _chip(
            context,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: LocalizationHelper.v2AudioPreparing(context),
            onPressed: null,
          );
        }

        if (isThis && state.phase == V2AudioUiPhase.unavailable) {
          return const SizedBox.shrink();
        }

        if (isThis && state.phase == V2AudioUiPhase.playing) {
          return _chip(
            context,
            icon: const Icon(Icons.pause, size: 20),
            label: LocalizationHelper.v2AudioPause(context),
            onPressed: () => controller.pause(),
            semantic: LocalizationHelper.v2AudioPause(context),
          );
        }

        if (isThis && state.phase == V2AudioUiPhase.paused) {
          return _chip(
            context,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: LocalizationHelper.v2AudioResume(context),
            onPressed: () => controller.resume(),
            semantic: LocalizationHelper.v2AudioResume(context),
          );
        }

        if (isThis &&
            (state.phase == V2AudioUiPhase.failed ||
                state.phase == V2AudioUiPhase.softError)) {
          return _chip(
            context,
            icon: const Icon(Icons.refresh, size: 20),
            label: LocalizationHelper.v2AudioRetry(context),
            onPressed: () async {
              await AnalyticsService.instance.audioClick(newsId: id);
              await controller.retry(
                articleId: id,
                language: language,
                generationEnabled: generationEnabled,
              );
            },
            semantic: LocalizationHelper.v2AudioRetry(context),
          );
        }

        return _chip(
          context,
          icon: const Icon(Icons.headphones, size: 20),
          label: LocalizationHelper.v2AudioListen(context),
          onPressed: () async {
            await AnalyticsService.instance.audioClick(newsId: id);
            await controller.onListenTap(
              articleId: id,
              language: language,
              generationEnabled: generationEnabled,
            );
          },
          semantic: LocalizationHelper.v2AudioListen(context),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    String? semantic,
  }) {
    final child = compact
        ? IconButton(
            onPressed: onPressed,
            icon: icon,
            tooltip: label,
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(label),
          );
    return Semantics(
      button: true,
      label: semantic ?? label,
      child: child,
    );
  }
}
