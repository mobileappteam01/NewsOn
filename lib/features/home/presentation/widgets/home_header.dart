import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../core/utils/shared_functions.dart';
import '../../../../core/widgets/language_selector_dialog.dart';
import '../../../../core/widgets/region_selector_bottom_sheet.dart';
import '../../../../providers/language_provider.dart';
import '../../../../providers/region_provider.dart';
import '../../../../providers/remote_config_provider.dart';

/// Premium V2 header: brand logo · language · region · menu.
///
/// Search lives in the V2 floating bottom nav (not here).
class V2HomeHeader extends StatelessWidget {
  const V2HomeHeader({
    super.key,
    this.onRegionChanged,
    this.onNewsLanguageChanged,
    this.onOpenFilters,
    this.filtersActive = false,
    this.onRefresh,
  });

  final Future<void> Function()? onRegionChanged;
  final Future<void> Function()? onNewsLanguageChanged;

  /// When set, the region globe is replaced by the V2 Home filter control.
  final Future<void> Function()? onOpenFilters;
  final bool filtersActive;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = context.watch<LanguageProvider>();
    final config = context.watch<RemoteConfigProvider>().config;
    final onSurface = theme.colorScheme.onSurface;
    final regionHighlighted = onOpenFilters == null &&
        context.select<RegionProvider, bool>((r) => r.hasAppliedRegion);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
          child: Row(
            children: [
              Semantics(
                label: 'NewsOn',
                image: true,
                child: showImage(
                  config.getAppNameLogoForTheme(theme.brightness),
                  BoxFit.contain,
                  height: 46,
                  width: 68,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Semantics(
                  button: true,
                  label:
                      '${LocalizationHelper.v2NewsLanguage(context)}: ${language.newsLanguageName}',
                  child: InkWell(
                    onTap: () => _openNewsLanguage(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              language.newsLanguageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: onSurface.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: onOpenFilters != null ? 'Filters' : LocalizationHelper.selectRegionTooltip(context),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: onOpenFilters != null
                      ? 'Filters'
                      : LocalizationHelper.selectRegionTooltip(context),
                  icon: Icon(
                    onOpenFilters != null
                        ? Icons.tune_rounded
                        : Icons.public,
                    size: 20,
                    color: (onOpenFilters != null
                            ? filtersActive
                            : regionHighlighted)
                        ? theme.colorScheme.primary
                        : onSurface,
                  ),
                  onPressed: () => onOpenFilters != null
                      ? onOpenFilters!.call()
                      : _openRegion(context),
                ),
              ),
              if (onRefresh != null)
                Semantics(
                  button: true,
                  label: 'Refresh',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    color: onSurface,
                    onPressed: () => onRefresh!.call(),
                  ),
                ),
              const Spacer(),
              Semantics(
                button: true,
                label: LocalizationHelper.menu(context),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: LocalizationHelper.menu(context),
                  icon: const Icon(Icons.menu_rounded),
                  color: onSurface,
                  onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNewsLanguage(BuildContext context) async {
    final before = context.read<LanguageProvider>().newsLanguageCode;
    await showDialog<void>(
      context: context,
      builder: (context) => const LanguageSelectorDialog(
        type: LanguageSelectorType.news,
      ),
    );
    if (!context.mounted) return;
    final after = context.read<LanguageProvider>().newsLanguageCode;
    if (after != before) {
      await AnalyticsService.instance.languageChange(newsLanguage: after);
      await onNewsLanguageChanged?.call();
    }
  }

  Future<void> _openRegion(BuildContext context) async {
    final region = context.read<RegionProvider>();
    if (!region.isInitialized) {
      await region.initialize();
    }
    if (!context.mounted) return;
    showRegionSelectorBottomSheet(
      context,
      onApplied: () async {
        final label = region.appliedRegion.toQueryParams().toString();
        await AnalyticsService.instance.regionChange(regionLabel: label);
        await onRegionChanged?.call();
      },
      onReset: () async {
        await AnalyticsService.instance.regionChange(regionLabel: null);
        await onRegionChanged?.call();
      },
    );
  }
}
