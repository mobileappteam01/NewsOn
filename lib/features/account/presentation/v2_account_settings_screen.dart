import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/localization_helper.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../providers/completed_news_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../screens/auth/auth_screen.dart';
import '../../home_v2/domain/v2_home_metadata.dart';
import '../data/v2_account_api.dart';
import '../domain/v2_account_profile.dart';

/// V2 Side Menu → Account Settings with real GET/PATCH persistence.
class V2AccountSettingsScreen extends StatefulWidget {
  const V2AccountSettingsScreen({
    super.key,
    this.controller,
    this.authScreenBuilder,
  });

  @visibleForTesting
  final V2AccountController? controller;

  /// Override post-logout destination (defaults to [AuthScreen]).
  @visibleForTesting
  final WidgetBuilder? authScreenBuilder;

  @override
  State<V2AccountSettingsScreen> createState() =>
      _V2AccountSettingsScreenState();
}

class _V2AccountSettingsScreenState extends State<V2AccountSettingsScreen> {
  late final V2AccountController _controller;
  late final bool _ownsController;

  final _username = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _city = TextEditingController();
  final _countrySearch = TextEditingController();

  String? _dateOfBirthYmd;
  String? _countrySlug;

  /// True while applying server profile → controllers (skips markDirty).
  bool _hydrating = false;
  String? _lastHydratedSignature;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? V2AccountController();
    _controller.addListener(_onController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  void _onController() {
    final state = _controller.state;
    if (state.phase == V2AccountPhase.loading) {
      _lastHydratedSignature = null;
    }
    final profile = state.profile;
    if (profile != null &&
        !_controller.isDirty &&
        (state.phase == V2AccountPhase.loaded ||
            state.phase == V2AccountPhase.saved)) {
      _hydrateFields(profile);
    }
    if (mounted) setState(() {});
  }

  void _hydrateFields(V2AccountProfile profile) {
    final signature = [
      profile.id,
      profile.username,
      profile.firstName,
      profile.lastName,
      profile.mobileNumber,
      profile.dateOfBirth ?? '',
      profile.country,
      profile.city,
    ].join('|');
    if (signature == _lastHydratedSignature &&
        _username.text == profile.username &&
        _firstName.text == profile.firstName &&
        _lastName.text == profile.lastName &&
        _mobile.text == profile.mobileNumber &&
        _city.text == profile.city) {
      _dateOfBirthYmd = profile.dateOfBirth;
      _countrySlug = profile.country.isEmpty ? null : profile.country;
      return;
    }
    _hydrating = true;
    try {
      if (_username.text != profile.username) {
        _username.value = TextEditingValue(
          text: profile.username,
          selection: TextSelection.collapsed(offset: profile.username.length),
        );
      }
      if (_firstName.text != profile.firstName) {
        _firstName.value = TextEditingValue(
          text: profile.firstName,
          selection: TextSelection.collapsed(offset: profile.firstName.length),
        );
      }
      if (_lastName.text != profile.lastName) {
        _lastName.value = TextEditingValue(
          text: profile.lastName,
          selection: TextSelection.collapsed(offset: profile.lastName.length),
        );
      }
      if (_mobile.text != profile.mobileNumber) {
        _mobile.value = TextEditingValue(
          text: profile.mobileNumber,
          selection:
              TextSelection.collapsed(offset: profile.mobileNumber.length),
        );
      }
      if (_city.text != profile.city) {
        _city.value = TextEditingValue(
          text: profile.city,
          selection: TextSelection.collapsed(offset: profile.city.length),
        );
      }
      _dateOfBirthYmd = profile.dateOfBirth;
      _countrySlug = profile.country.isEmpty ? null : profile.country;
      _lastHydratedSignature = signature;
    } finally {
      _hydrating = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    if (_ownsController) _controller.dispose();
    _username.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _city.dispose();
    _countrySearch.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_controller.isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved account changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _pickDob() async {
    final initial = _parseYmd(_dateOfBirthYmd) ??
        DateTime.utc(DateTime.now().year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.utc(1920, 1, 1),
      lastDate: DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      helpText: LocalizationHelper.dateOfBirth(context),
    );
    if (picked == null) return;
    // Format from calendar components — avoid timezone shift.
    setState(() {
      _dateOfBirthYmd =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
    _controller.markDirty();
  }

  DateTime? _parseYmd(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (m == null) return null;
    return DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  String _dobDisplay() {
    final d = _parseYmd(_dateOfBirthYmd);
    if (d == null) return 'Select date';
    return DateFormat.yMMMMd().format(d);
  }

  Future<void> _save() async {
    final ok = await _controller.save(
      username: _username.text,
      firstName: _firstName.text,
      lastName: _lastName.text,
      mobileNumber: _mobile.text,
      dateOfBirthYmd: _dateOfBirthYmd,
      country: _countrySlug,
      city: _city.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account settings saved')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => showLogoutModalBottomSheet(context),
    );
    if (shouldLogout != true || !mounted) return;

    await _controller.logout();
    if (!mounted) return;
    try {
      await context.read<CompletedNewsProvider>().clearUser();
    } catch (_) {
      // Provider may be absent in isolated widget tests.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: widget.authScreenBuilder ??
            (_) => const AuthScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _openCountryPicker() async {
    if (_controller.countriesLoading) return;
    if (_controller.countries.isEmpty) {
      await _controller.loadCountries();
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _CountryPickerSheet(
          countries: _controller.countries,
          selected: _countrySlug,
          loading: _controller.countriesLoading,
          error: _controller.countriesError,
          onRetry: _controller.loadCountries,
        );
      },
    );
    if (selected == null) return;
    setState(() => _countrySlug = selected.isEmpty ? null : selected);
    _controller.markDirty();
  }

  String _countryLabel() {
    final slug = _countrySlug;
    if (slug == null || slug.isEmpty) return 'Select country';
    for (final c in _controller.countries) {
      if (c.slug == slug || c.name == slug) return c.name;
    }
    return slug;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, _) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final state = _controller.state;

        return PopScope(
          canPop: !_controller.isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _onWillPop() && mounted) {
              navigator.pop();
            }
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: commonappBar(
                      config.getAppNameLogoForTheme(theme.brightness),
                      () async {
                        final navigator = Navigator.of(context);
                        if (await _onWillPop() && mounted) {
                          navigator.pop();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocalizationHelper.accountSettings(context),
                        style: GoogleFonts.playfairDisplay(
                          color: config.primaryColorValue,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildBody(theme, state)),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: state.isSaving || state.isLoading
                                  ? null
                                  : _save,
                              child: state.isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: 48,
                            child: ElevatedButton(
                              key: const Key('v2_account_logout'),
                              onPressed: state.isSaving || state.isLoading
                                  ? null
                                  : _handleLogout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: config.primaryColorValue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                LocalizationHelper.logout(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, V2AccountState state) {
    if (state.isLoading && !state.hasProfile) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (state.phase == V2AccountPhase.apiError && !state.hasProfile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error ?? 'Could not load profile',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _controller.load,
                child: Text(LocalizationHelper.retry(context)),
              ),
            ],
          ),
        ),
      );
    }

    final fieldErrors = state.fieldErrors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (state.error != null &&
            (state.phase == V2AccountPhase.apiError ||
                state.phase == V2AccountPhase.validationError))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              state.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        _Field(
          label: 'Username',
          controller: _username,
          error: fieldErrors['username'],
          onChanged: (_) {
            if (!_hydrating) _controller.markDirty();
          },
        ),
        _Field(
          label: 'First Name',
          controller: _firstName,
          error: fieldErrors['firstName'],
          onChanged: (_) {
            if (!_hydrating) _controller.markDirty();
          },
        ),
        _Field(
          label: 'Last Name',
          controller: _lastName,
          error: fieldErrors['lastName'],
          onChanged: (_) {
            if (!_hydrating) _controller.markDirty();
          },
        ),
        const SizedBox(height: 8),
        Text('Date of Birth', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _pickDob,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          child: Text(_dobDisplay()),
        ),
        if (fieldErrors['dateOfBirth'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              fieldErrors['dateOfBirth']!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        _Field(
          label: 'Mobile Number',
          controller: _mobile,
          keyboardType: TextInputType.phone,
          error: fieldErrors['mobileNumber'],
          onChanged: (_) {
            if (!_hydrating) _controller.markDirty();
          },
        ),
        _Field(
          label: 'City',
          controller: _city,
          error: fieldErrors['city'],
          onChanged: (_) {
            if (!_hydrating) _controller.markDirty();
          },
        ),
        const SizedBox(height: 8),
        Text('Country', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _openCountryPicker,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          child: Row(
            children: [
              Expanded(child: Text(_countryLabel())),
              if (_controller.countriesLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.expand_more),
            ],
          ),
        ),
        if (fieldErrors['country'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              fieldErrors['country']!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        if (_controller.countriesError != null)
          TextButton(
            onPressed: _controller.loadCountries,
            child: Text(_controller.countriesError!),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.error,
    this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<V2RegionOption> countries;
  final String? selected;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.countries.where((c) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.slug.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              'Select country',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (widget.loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (widget.error != null)
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: widget.onRetry,
                    child: Text(widget.error!),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(child: Text('No countries found')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: const Text('Clear'),
                        onTap: () => Navigator.pop(context, ''),
                      );
                    }
                    final option = filtered[index - 1];
                    final selected = option.slug == widget.selected ||
                        option.name == widget.selected;
                    return ListTile(
                      title: Text(option.name),
                      trailing: selected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(context, option.slug),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
