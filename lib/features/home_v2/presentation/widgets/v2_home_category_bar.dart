import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../domain/v2_home_metadata.dart';

/// Horizontal V2 Home category row under the header.
///
/// Same multi-select semantics as the former filter-sheet chips: each chip
/// toggles its slug in the temporary Home filter; "All" clears the temporary
/// categories so the backend applies saved preferences again.
class V2HomeCategoryBar extends StatelessWidget {
  const V2HomeCategoryBar({
    super.key,
    required this.categories,
    required this.selectedSlugs,
    required this.pending,
    required this.failed,
    required this.onToggle,
    required this.onSelectAll,
    this.onRetry,
  });

  /// Row height is fixed so loading → loaded never shifts the feed.
  static const double height = 44;
  static const double _chipMaxWidth = 168;

  final List<V2CategoryOption> categories;
  final List<String> selectedSlugs;
  final bool pending;
  final bool failed;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSlugs.toSet();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: height,
        child: pending
            ? const _PlaceholderRow()
            : ListView.separated(
                key: const PageStorageKey<String>('v2_home_category_bar'),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 1 + categories.length + (failed ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _CategoryChip(
                      key: const ValueKey('v2_category_all'),
                      label: LocalizationHelper.v2HomeCategoryAll(context),
                      selected: selected.isEmpty,
                      onTap: selected.isEmpty ? null : onSelectAll,
                    );
                  }
                  if (i > categories.length) {
                    return _RetryChip(onTap: onRetry);
                  }
                  final category = categories[i - 1];
                  return _CategoryChip(
                    key: ValueKey('v2_category_${category.slug}'),
                    label: capitalizeCategoryLabel(category.name),
                    selected: selected.contains(category.slug),
                    onTap: () => onToggle(category.slug),
                  );
                },
              ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final background = selected
        ? scheme.primary
        : (dark
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.42));
    final border = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.12);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            maxWidth: V2HomeCategoryBar._chipMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(selected ? 9 : 12, 0, 12, 0),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 14, color: foreground),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: foreground,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final label = LocalizationHelper.retry(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('v2_category_retry'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 16,
                color: onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow();

  @override
  Widget build(BuildContext context) {
    final fill =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    return ListView(
      key: const ValueKey('v2_category_placeholder'),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        for (final width in const [44.0, 76.0, 64.0, 88.0, 70.0, 80.0])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
      ],
    );
  }
}
