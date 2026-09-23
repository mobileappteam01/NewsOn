import 'package:flutter/material.dart';

import 'v2_vintage_paper_background.dart';

/// Compact icon-only floating navigation item.
class V2BottomNavItem extends StatelessWidget {
  const V2BottomNavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.selectedColor,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selectedColor ?? theme.colorScheme.primary;
    final color = isSelected
        ? accent
        : theme.colorScheme.onSurface.withValues(alpha: 0.48);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 23,
                  color: color,
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: isSelected ? 14 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating 4-icon pill: Home · For You · Bookmarks · Search.
///
/// [currentIndex] is the **nav** highlight (0–3):
/// 0 Home · 1 For You · 2 Bookmarks · 3 Search.
///
/// Pill surface always matches the V2 Home stage background
/// ([V2VintagePaperBackground.stageBaseFor]) — no tab-specific fills.
class V2FloatingBottomNav extends StatelessWidget {
  const V2FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onHome,
    required this.onForYou,
    required this.onBookmarks,
    required this.onSearch,
    required this.homeLabel,
    required this.forYouLabel,
    required this.bookmarksLabel,
    required this.searchLabel,
  });

  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onForYou;
  final VoidCallback onBookmarks;
  final VoidCallback onSearch;
  final String homeLabel;
  final String forYouLabel;
  final String bookmarksLabel;
  final String searchLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Same token as V2 Home / Scaffold stage background.
    final Color pill = V2VintagePaperBackground.stageBaseFor(theme.brightness);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFD2C2A6).withValues(alpha: 0.50);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        child: AnimatedContainer(
          key: const ValueKey('v2_nav_pill_surface'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: pill,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: border, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: V2BottomNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: homeLabel,
                    isSelected: currentIndex == 0,
                    onTap: onHome,
                  ),
                ),
                Expanded(
                  child: V2BottomNavItem(
                    icon: Icons.auto_awesome_outlined,
                    selectedIcon: Icons.auto_awesome,
                    label: forYouLabel,
                    isSelected: currentIndex == 1,
                    onTap: onForYou,
                  ),
                ),
                Expanded(
                  child: V2BottomNavItem(
                    icon: Icons.bookmark_border_rounded,
                    selectedIcon: Icons.bookmark_rounded,
                    label: bookmarksLabel,
                    isSelected: currentIndex == 2,
                    onTap: onBookmarks,
                  ),
                ),
                Expanded(
                  child: V2BottomNavItem(
                    icon: Icons.search_rounded,
                    selectedIcon: Icons.search_rounded,
                    label: searchLabel,
                    isSelected: currentIndex == 3,
                    onTap: onSearch,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
