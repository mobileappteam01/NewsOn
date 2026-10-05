import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../../../data/services/dynamic_localization_service.dart';
import '../../data/v2_home_api.dart';
import '../../domain/home_filter_state.dart';
import '../../domain/v2_home_date_window.dart';
import '../../domain/v2_home_metadata.dart';

/// Opens the V2 Home filter sheet (location + date). Categories live in the
/// Home category row; the draft carries the current categories through
/// unchanged.
///
/// Returns the draft only when the user taps Apply. Dismiss returns null
/// and must not change the live feed.
Future<HomeFilterState?> showV2HomeFilterSheet(
  BuildContext context, {
  required HomeFilterState initial,
  V2HomeMetadataApi? metadataApi,
}) {
  return showModalBottomSheet<HomeFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => V2HomeFilterSheet(
      initial: initial,
      metadataApi: metadataApi,
    ),
  );
}

class V2HomeFilterSheet extends StatefulWidget {
  const V2HomeFilterSheet({
    super.key,
    required this.initial,
    this.metadataApi,
    this.clock,
  });

  final HomeFilterState initial;
  final V2HomeMetadataApi? metadataApi;

  /// Current instant for the Asia/Kolkata date window. Tests only.
  final DateTime Function()? clock;

  @override
  State<V2HomeFilterSheet> createState() => _V2HomeFilterSheetState();
}

class _V2HomeFilterSheetState extends State<V2HomeFilterSheet> {
  late HomeFilterState _draft;
  late final V2HomeMetadataApi _api;

  List<V2RegionOption> _countries = const [];
  List<V2RegionOption> _states = const [];
  List<V2RegionOption> _cities = const [];

  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;
  bool _countryError = false;
  bool _stateError = false;
  bool _cityError = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _api = widget.metadataApi ?? V2HomeMetadataApi();
    _loadCountries();
    final country = _draft.country;
    final state = _draft.state;
    if (country != null && country.isNotEmpty) {
      _loadStates(country);
    }
    if (country != null &&
        country.isNotEmpty &&
        state != null &&
        state.isNotEmpty) {
      _loadCities(country, state);
    }
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countryError = false;
    });
    try {
      final items = await _api.fetchCountries();
      if (!mounted) return;
      setState(() {
        _countries = items;
        _loadingCountries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCountries = false;
        _countryError = true;
      });
    }
  }

  Future<void> _loadStates(String country) async {
    setState(() {
      _loadingStates = true;
      _stateError = false;
      _states = const [];
    });
    try {
      final items = await _api.fetchStates(country);
      if (!mounted) return;
      setState(() {
        _states = items;
        _loadingStates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStates = false;
        _stateError = true;
      });
    }
  }

  Future<void> _loadCities(String country, String state) async {
    setState(() {
      _loadingCities = true;
      _cityError = false;
      _cities = const [];
    });
    try {
      final items = await _api.fetchCities(country: country, state: state);
      if (!mounted) return;
      setState(() {
        _cities = items;
        _loadingCities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _cityError = true;
      });
    }
  }

  void _onCountry(String? slug) {
    setState(() {
      _draft = _draft.selectCountry(slug);
      _states = const [];
      _cities = const [];
    });
    if (slug != null && slug.isNotEmpty) _loadStates(slug);
  }

  void _onState(String? slug) {
    setState(() {
      _draft = _draft.selectState(slug);
      _cities = const [];
    });
    final country = _draft.country;
    if (slug != null &&
        slug.isNotEmpty &&
        country != null &&
        country.isNotEmpty) {
      _loadCities(country, slug);
    }
  }

  Future<void> _pickDate() async {
    final now = _now;
    final dynamicL10n = DynamicLocalizationService();
    final picked = await showDatePicker(
      context: context,
      initialDate: V2HomeDateWindow.initialPickerDay(_draft.date, now: now),
      firstDate: V2HomeDateWindow.firstDay(now: now),
      lastDate: V2HomeDateWindow.today(now: now),
      currentDate: V2HomeDateWindow.today(now: now),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      locale: V2HomeDateWindow.pickerLocale(
        dynamicL10n.isInitialized ? dynamicL10n.currentLanguageCode : null,
        Localizations.localeOf(context),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _draft = _draft.selectDate(V2HomeDateWindow.format(picked));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final optionsError = LocalizationHelper.v2FilterOptionsError(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.66,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          LocalizationHelper.v2FilterTitle(context),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Clears this sheet's filters (location + date) and
                          // returns immediately. Home row categories are kept.
                          Navigator.of(context).pop(
                            HomeFilterState(
                              selectedCategorySlugs:
                                  widget.initial.selectedCategorySlugs,
                            ),
                          );
                        },
                        child: Text(
                          LocalizationHelper.v2FilterClearAll(context),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    children: [
                      _SectionTitle(
                        text: LocalizationHelper.v2FilterLocation(context),
                      ),
                      const SizedBox(height: 8),
                      _LocationField(
                        key: const ValueKey('v2_filter_country'),
                        label: LocalizationHelper.v2FilterCountry(context),
                        loading: _loadingCountries,
                        error: _countryError ? optionsError : null,
                        onRetry: _loadCountries,
                        value: _draft.country,
                        options: _countries,
                        enabled: true,
                        onChanged: _onCountry,
                      ),
                      const SizedBox(height: 10),
                      _LocationField(
                        key: const ValueKey('v2_filter_state'),
                        label: LocalizationHelper.v2FilterState(context),
                        loading: _loadingStates,
                        error: _stateError ? optionsError : null,
                        onRetry: _draft.country == null
                            ? null
                            : () => _loadStates(_draft.country!),
                        value: _draft.state,
                        options: _states,
                        enabled: _draft.country != null,
                        onChanged: _onState,
                      ),
                      const SizedBox(height: 10),
                      _LocationField(
                        key: const ValueKey('v2_filter_city'),
                        label: LocalizationHelper.v2FilterCity(context),
                        loading: _loadingCities,
                        error: _cityError ? optionsError : null,
                        onRetry: (_draft.country == null || _draft.state == null)
                            ? null
                            : () => _loadCities(_draft.country!, _draft.state!),
                        value: _draft.district,
                        options: _cities,
                        enabled: _draft.state != null,
                        onChanged: (slug) {
                          setState(() => _draft = _draft.selectDistrict(slug));
                        },
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        text: LocalizationHelper.v2FilterDate(context),
                      ),
                      const SizedBox(height: 8),
                      _DateField(
                        label: LocalizationHelper.v2FilterDate(context),
                        value: _draft.date,
                        now: _now,
                        onTap: _pickDate,
                        onClear: () => setState(
                          () => _draft = _draft.selectDate(null),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_draft),
                        child: Text(
                          LocalizationHelper.v2FilterApply(context),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _RetryLine extends StatelessWidget {
  const _RetryLine({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(LocalizationHelper.retry(context)),
        ),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    super.key,
    required this.label,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String? value;
  final List<V2RegionOption> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value?.trim();
    final hasSelection = selected != null && selected.isNotEmpty;
    final showRetry = error != null && onRetry != null;
    if (showRetry && !hasSelection) {
      return _RetryLine(message: error!, onRetry: onRetry!);
    }
    // A saved value missing from the loaded list (deactivated region, failed
    // load) stays visible instead of falling back to "Any".
    final items = sortRegionOptions([
      ...options,
      if (hasSelection && !options.any((o) => o.slug == selected))
        V2RegionOption(slug: selected, name: selected),
    ]);
    final any = LocalizationHelper.v2FilterAny(context);
    final field = InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: hasSelection ? selected : null,
                hint: Text(
                  enabled
                      ? any
                      : LocalizationHelper.v2FilterSelectAbove(context),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(any),
                  ),
                  for (final option in items)
                    DropdownMenuItem<String?>(
                      value: option.slug,
                      child: Text(
                        formatRegionLabel(option.name),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
    );
    if (!showRetry) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        _RetryLine(message: error!, onRetry: onRetry!),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.now,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String? value;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onClear;

  String _display(BuildContext context, DateTime day) {
    final today = V2HomeDateWindow.today(now: now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final formatted = MaterialLocalizations.of(context).formatMediumDate(day);
    if (DateUtils.isSameDay(day, today)) {
      return '${LocalizationHelper.today(context)} · $formatted';
    }
    if (DateUtils.isSameDay(day, yesterday)) {
      return '${LocalizationHelper.yesterday(context)} · $formatted';
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = V2HomeDateWindow.parse(value);
    final text = day != null
        ? _display(context, day)
        : LocalizationHelper.v2FilterAnyDate(context);
    return InkWell(
      key: const ValueKey('v2_filter_date'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: day != null
              ? IconButton(
                  key: const ValueKey('v2_filter_date_clear'),
                  tooltip: LocalizationHelper.v2FilterClearDate(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: day == null
                  ? theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
