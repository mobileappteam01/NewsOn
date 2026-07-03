import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/localization_helper.dart';
import '../../providers/region_provider.dart';
import '../../providers/remote_config_provider.dart';

typedef RegionFeedRefreshCallback = Future<void> Function();

void showRegionSelectorBottomSheet(
  BuildContext context, {
  required RegionFeedRefreshCallback onApplied,
  required RegionFeedRefreshCallback onReset,
}) {
  context.read<RegionProvider>().syncDraftFromApplied();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _RegionSelectorSheet(
          onApplied: onApplied,
          onReset: onReset,
        ),
      );
    },
  );
}

class _RegionSelectorSheet extends StatelessWidget {
  const _RegionSelectorSheet({
    required this.onApplied,
    required this.onReset,
  });

  final RegionFeedRefreshCallback onApplied;
  final RegionFeedRefreshCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = context.watch<RemoteConfigProvider>().config;

    return Consumer<RegionProvider>(
      builder: (context, regionProvider, _) {
        final draft = regionProvider.draftRegion;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocalizationHelper.selectRegion(context),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: LocalizationHelper.close(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (regionProvider.error != null) ...[
                  Text(
                    regionProvider.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _RegionDropdown(
                  label: LocalizationHelper.regionCountry(context),
                  value: draft.country,
                  items: regionProvider.countries.map((r) => r.name).toList(),
                  isLoading: regionProvider.isLoadingCountries,
                  primaryColor: config.primaryColorValue,
                  onChanged: regionProvider.onCountryChanged,
                ),
                const SizedBox(height: 12),
                _RegionDropdown(
                  label: LocalizationHelper.regionState(context),
                  value: draft.state,
                  items: regionProvider.states.map((r) => r.name).toList(),
                  isLoading: regionProvider.isLoadingStates,
                  enabled: draft.country != null && draft.country!.isNotEmpty,
                  primaryColor: config.primaryColorValue,
                  onChanged: regionProvider.onStateChanged,
                ),
                if (regionProvider.showDistrictDropdown) ...[
                  const SizedBox(height: 12),
                  _RegionDropdown(
                    label: LocalizationHelper.regionDistrict(context),
                    value: draft.district,
                    items: regionProvider.districts.map((r) => r.name).toList(),
                    isLoading: regionProvider.isLoadingDistricts,
                    enabled: draft.state != null && draft.state!.isNotEmpty,
                    primaryColor: config.primaryColorValue,
                    onChanged: regionProvider.onDistrictChanged,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: regionProvider.isApplying
                            ? null
                            : () async {
                                await regionProvider.resetRegion();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                await onReset();
                              },
                        child: Text(LocalizationHelper.reset(context)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: regionProvider.isApplying
                            ? null
                            : () async {
                                final applied =
                                    await regionProvider.applySelection();
                                if (applied.country == null ||
                                    applied.country!.isEmpty) {
                                  return;
                                }
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                await onApplied();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: config.primaryColorValue,
                        ),
                        child: regionProvider.isApplying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(LocalizationHelper.apply(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  const _RegionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.isLoading,
    required this.primaryColor,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> items;
  final bool isLoading;
  final bool enabled;
  final Color primaryColor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: value != null && items.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            hint: Text(
              LocalizationHelper.selectOption(context),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            selectedItemBuilder: (context) {
              return items
                  .map(
                    (name) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList();
            },
            items: items
                .map(
                  (name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
      ],
    );
  }
}
