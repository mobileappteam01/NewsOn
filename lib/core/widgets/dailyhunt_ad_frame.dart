import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/localization_helper.dart';

/// Dailyhunt-style ad frame: rounded border with centered "Ad" chip on top.
class DailyhuntAdFrame extends StatelessWidget {
  const DailyhuntAdFrame({
    super.key,
    required this.child,
    this.label,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget child;
  final String? label;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : const Color(0xFFB39DDB);
    final labelText = label ?? LocalizationHelper.adLabel(context);
    final background = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surface.withValues(alpha: 0.92);

    return Padding(
      padding: margin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.6),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
              child: child,
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                labelText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: borderColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
