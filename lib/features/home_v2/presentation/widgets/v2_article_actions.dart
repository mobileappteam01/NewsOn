import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact centered editorial CTA — opens V2 article detail.
class V2ArticleActions extends StatelessWidget {
  const V2ArticleActions({
    super.key,
    required this.onViewFullArticle,
    this.publisherName,
  });

  final VoidCallback onViewFullArticle;

  /// Unused — retained so existing call sites keep compiling.
  final String? publisherName;

  static const String label = 'Read Full Article';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final fill = accent.withValues(alpha: isDark ? 0.12 : 0.07);
    final border = accent.withValues(alpha: isDark ? 0.45 : 0.35);

    return Center(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onViewFullArticle,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              height: 40,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined, color: accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: accent.withValues(alpha: 0.9),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
