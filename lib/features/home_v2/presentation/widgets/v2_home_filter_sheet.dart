import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/v2_home_api.dart';
import '../../domain/home_filter_state.dart';
import '../../domain/v2_home_metadata.dart';

/// Opens the V2 Home filter sheet.
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
  });

  final HomeFilterState initial;
  final V2HomeMetadataApi? metadataApi;

  @override
  State<V2HomeFilterSheet> createState() => _V2HomeFilterSheetState();
}

class _V2HomeFilterSheetState extends State<V2HomeFilterSheet> {
  late HomeFilterState _draft;
  late final V2HomeMetadataApi _api;

  List<V2CategoryOption> _categories = const [];
  List<V2RegionOption> _countries = const [];
  List<V2RegionOption> _states = const [];
  List<V2RegionOption> _cities = const [];

  bool _loadingCategories = true;
  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;
  String? _categoryError;
  String? _countryError;
  String? _stateError;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _api = widget.metadataApi ?? V2HomeMetadataApi();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final items = await _api.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = items;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoryError = 'Could not load categories';
      });
    }
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countryError = null;
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
        _countryError = 'Could not load countries';
      });
    }
  }

  Future<void> _loadStates(String country) async {
    setState(() {
      _loadingStates = true;
      _stateError = null;
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
        _stateError = 'Could not load states';
      });
    }
  }

  Future<void> _loadCities(String country, String state) async {
    setState(() {
      _loadingCities = true;
      _cityError = null;
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
        _cityError = 'Could not load cities';
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

  String? _labelFor(List<V2RegionOption> options, String? slug) {
    if (slug == null || slug.isEmpty) return null;
    for (final option in options) {
      if (option.slug == slug) return option.name;
    }
    return slug;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final countryName = _labelFor(_countries, _draft.country);
    final stateName = _labelFor(_states, _draft.state);
    final cityName = _labelFor(_cities, _draft.district);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
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
                          'Filters',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Clear All removes the temporary filter and returns
                          // immediately so Home reloads with saved preferences.
                          Navigator.of(context).pop(const HomeFilterState());
                        },
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_draft.isActive)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [
                          if (_draft.hasCategories)
                            'Categories  ${_draft.categoryCount} selected',
                          if (countryName != null) countryName,
                          if (stateName != null) stateName,
                          if (cityName != null) cityName,
                        ].join('\n'),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.35,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    children: [
                      const _SectionTitle(text: 'Categories'),
                      const SizedBox(height: 8),
                      if (_loadingCategories)
                        const _InlineLoading()
                      else if (_categoryError != null)
                        _RetryLine(
                          message: _categoryError!,
                          onRetry: _loadCategories,
                        )
                      else if (_categories.isEmpty)
                        const _Hint('No categories available')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in _categories)
                              FilterChip(
                                label: Text(
                                  capitalizeCategoryLabel(category.name),
                                ),
                                selected: _draft.selectedCategorySlugs
                                    .contains(category.slug),
                                onSelected: (_) {
                                  setState(() {
                                    _draft = _draft.toggleCategory(category.slug);
                                  });
                                },
                              ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      const _SectionTitle(text: 'Location'),
                      const SizedBox(height: 8),
                      _LocationField(
                        label: 'Country',
                        loading: _loadingCountries,
                        error: _countryError,
                        onRetry: _loadCountries,
                        value: _draft.country,
                        options: _countries,
                        enabled: true,
                        onChanged: _onCountry,
                      ),
                      const SizedBox(height: 10),
                      _LocationField(
                        label: 'State',
                        loading: _loadingStates,
                        error: _stateError,
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
                        label: 'City / District',
                        loading: _loadingCities,
                        error: _cityError,
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
                          'Apply Filters',
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

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: Theme.of(context).hintColor,
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
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
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
    if (error != null && onRetry != null) {
      return _RetryLine(message: error!, onRetry: onRetry!);
    }
    return InputDecorator(
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
                value: options.any((o) => o.slug == value) ? value : null,
                hint: Text(enabled ? 'Any' : 'Select above'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Any'),
                  ),
                  for (final option in options)
                    DropdownMenuItem<String?>(
                      value: option.slug,
                      child: Text(
                        option.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
    );
  }
}
