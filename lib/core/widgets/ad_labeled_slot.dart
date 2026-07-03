import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/localization_helper.dart';

/// Wraps an ad unit with a subtle "Sponsored" label (policy-friendly disclosure).
class AdLabeledSlot extends StatelessWidget {
  const AdLabeledSlot({
    super.key,
    required this.child,
    this.label,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final Widget child;
  final String? label;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withValues(alpha: 0.5);
    final labelText = label ?? LocalizationHelper.sponsored(context);

    return Padding(
      // margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  labelText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
