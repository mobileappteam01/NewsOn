import 'package:flutter/material.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/category_model.dart';
import 'home_section_header.dart';

/// Focused horizontal category discovery — not the full catalog.
class CategoryExplorer extends StatelessWidget {
  const CategoryExplorer({
    super.key,
    required this.categories,
    this.selected,
    this.onCategorySelected,
    this.onExploreAll,
    this.onLatestTap,
    this.onForYouTap,
    this.error,
  });

  final List<CategoryModel> categories;
  final CategoryModel? selected;
  final ValueChanged<CategoryModel>? onCategorySelected;
  final VoidCallback? onExploreAll;
  final VoidCallback? onLatestTap;
  final VoidCallback? onForYouTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: LocalizationHelper.v2Explore(context),
          trailingLabel: LocalizationHelper.v2ExploreAll(context),
          onTrailingTap: onExploreAll,
        ),
        if (error != null && categories.isEmpty)
          HomeSectionError(message: error!)
        else
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: LocalizationHelper.v2Latest(context),
                  selected: selected == null,
                  onTap: onLatestTap,
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: LocalizationHelper.forYou(context),
                  selected: false,
                  onTap: onForYouTap,
                ),
                ...categories.map((c) {
                  final name = c.name.isNotEmpty
                      ? '${c.name[0].toUpperCase()}${c.name.substring(1)}'
                      : c.name;
                  final isSelected = selected?.id == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: name,
                      selected: isSelected,
                      onTap: () {
                        AnalyticsService.instance
                            .categoryView(category: c.name);
                        onCategorySelected?.call(c);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        if (categories.isEmpty && error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              LocalizationHelper.v2Loading(context),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap?.call(),
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
