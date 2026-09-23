import 'package:flutter/material.dart';

/// Compact editorial reader position: "20 of 50" + thin progress bar.
class V2ReaderProgress extends StatelessWidget {
  const V2ReaderProgress({
    super.key,
    required this.index,
    required this.total,
    this.compact = false,
  });

  final int index;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final current = (index + 1).clamp(1, total);
    final progress = current / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$current of $total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontSize: compact ? 11 : 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: compact ? 72 : 88,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2.5,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
