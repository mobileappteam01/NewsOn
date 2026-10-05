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
import '../domain/v2_account_validation.dart';

/// V2 Side Menu → Account Settings with real GET/PATCH persistence.
class V2AccountSettingsScreen extends StatefulWidget {
  const V2AccountSettingsScreen({
    super.key,
    this.controller,
    this.authScreenBuilder,
  });

  static const usernameFieldKey = Key('v2_account_username');
  static const firstNameFieldKey = Key('v2_account_first_name');
  static const lastNameFieldKey = Key('v2_account_last_name');
  static const saveButtonKey = Key('v2_account_save');
  static const editButtonKey = Key('v2_account_edit');

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

  TextEditingController _username = TextEditingController();
  TextEditingController _firstName = TextEditingController();
  TextEditingController _lastName = TextEditingController();
  TextEditingController _mobile = TextEditingController();
  TextEditingController _city = TextEditingController();
  final _countrySearch = TextEditingController();

  final _usernameFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _mobileFocus = FocusNode();

  String? _dateOfBirthYmd;
  String? _countrySlug;

  /// View mode (false) is read-only; the AppBar Edit icon switches to edit
  /// mode, and a successful Save switches back.
  bool _editing = false;

  /// True while applying server profile → controllers (skips markDirty).
  bool _hydrating = false;
  String? _lastHydratedSignature;

  /// Fields the user typed in or left; their errors are validated live.
  final Set<String> _interacted = <String>{};

  /// Bumped when the form is rebuilt from a freshly saved profile.
  int _formEpoch = 0;
  late int _appliedSaveRevision;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? V2AccountController();
    _appliedSaveRevision = _controller.saveRevision;
    _controller.addListener(_onController);
    _watchFocus(_usernameFocus, 'username');
    _watchFocus(_firstNameFocus, 'firstName');
    _watchFocus(_lastNameFocus, 'lastName');
    _watchFocus(_mobileFocus, 'mobileNumber');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  void _watchFocus(FocusNode node, String field) {
    // Enabling a field (entering edit mode) also notifies; only a real
    // focus → unfocus transition counts as leaving it.
    var hadFocus = false;
    node.addListener(() {
      final left = hadFocus && !node.hasFocus;
      hadFocus = node.hasFocus;
      if (!left || !mounted) return;
      setState(() => _interacted.add(field));
    });
  }

  void _onController() {
    final state = _controller.state;
    if (state.phase == V2AccountPhase.loading) {
      _lastHydratedSignature = null;
    }
    final profile = state.profile;
    if (profile != null &&
        state.phase == V2AccountPhase.saved &&
        _controller.saveRevision != _appliedSaveRevision) {
      _resetFormFrom(profile);
    } else if (profile != null &&
        !_controller.isDirty &&
        (state.phase == V2AccountPhase.loaded ||
            state.phase == V2AccountPhase.saved)) {
      _hydrateFields(profile);
    }
    if (mounted) setState(() {});
  }

  static String _signatureOf(V2AccountProfile profile) => [
        profile.id,
        profile.username,
        profile.firstName,
        profile.lastName,
        profile.mobileNumber,
        profile.dateOfBirth ?? '',
        profile.country,
        profile.city,
      ].join('|');

  /// After a successful save: drop focus (closes the keyboard), recreate the
  /// controllers from the reloaded profile and rebuild the form once.
  void _resetFormFrom(V2AccountProfile profile) {
    _appliedSaveRevision = _controller.saveRevision;
    FocusManager.instance.primaryFocus?.unfocus();
    final previous = [_username, _firstName, _lastName, _mobile, _city];
    _username = TextEditingController(text: profile.username);
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _mobile = TextEditingController(text: profile.mobileNumber);
    _city = TextEditingController(text: profile.city);
    _dateOfBirthYmd = profile.dateOfBirth;
    _countrySlug = profile.country.isEmpty ? null : profile.country;
    _lastHydratedSignature = _signatureOf(profile);
    _interacted.clear();
    _formEpoch++;
    // The old fields still reference these until the rebuilt form replaces
    // them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in previous) {
        c.dispose();
      }
    });
  }

  void _hydrateFields(V2AccountProfile profile) {
    final signature = _signatureOf(profile);
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
    _usernameFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_controller.isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocalizationHelper.v2AccountDiscardTitle(context)),
        content: Text(LocalizationHelper.v2AccountDiscardMessage(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationHelper.v2AccountKeepEditing(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocalizationHelper.v2AccountDiscard(context)),
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
    if (d == null) return LocalizationHelper.v2AccountSelectDate(context);
    return DateFormat.yMMMMd().format(d);
  }

  void _enterEditMode() {
    final profile = _controller.state.profile;
    if (profile == null) return;
    if (!_controller.isDirty) _hydrateFields(profile);
    setState(() {
      _interacted.clear();
      _editing = true;
    });
  }

  Future<void> _save() async {
    setState(() => _interacted.addAll(_validatedFields));
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
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationHelper.v2AccountSaved(context))),
      );
    }
  }

  static const _validatedFields = [
    'username',
    'firstName',
    'lastName',
    'mobileNumber',
  ];

  Map<String, String> _liveErrors() => _controller.validate(
        username: _username.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        mobileNumber: _mobile.text,
        dateOfBirthYmd: _dateOfBirthYmd,
        country: _countrySlug,
        city: _city.text,
      );

  void _onFieldChanged(String field) {
    if (_hydrating) return;
    _controller.markDirty();
    setState(() => _interacted.add(field));
  }

  String? _fieldError(
    String field,
    Map<String, String> live,
    Map<String, String> submitted,
  ) {
    if (!_editing) return null;
    final code = _interacted.contains(field) ? live[field] : submitted[field];
    return code == null ? null : _errorMessage(field, code);
  }

  String _errorMessage(String field, String code) {
    switch (code) {
      case V2AccountFieldError.required:
        return field == 'username'
            ? LocalizationHelper.v2AccountUsernameRequired(context)
            : LocalizationHelper.v2AccountFirstNameRequired(context);
      case V2AccountFieldError.tooShort:
        return field == 'username'
            ? LocalizationHelper.v2AccountUsernameTooShort(context)
            : LocalizationHelper.v2AccountFirstNameTooShort(context);
      case V2AccountFieldError.placeholder:
        return LocalizationHelper.v2AccountUsernamePlaceholder(context);
      case V2AccountFieldError.invalidMobile:
        return LocalizationHelper.v2AccountInvalidMobile(context);
      case V2AccountFieldError.invalidDate:
        return LocalizationHelper.v2AccountInvalidDate(context);
      case V2AccountFieldError.invalidCountry:
        return LocalizationHelper.v2AccountInvalidCountry(context);
    }
    return code;
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
    if (slug == null || slug.isEmpty) {
      return LocalizationHelper.selectCountry(context);
    }
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocalizationHelper.accountSettings(context),
                            style: GoogleFonts.playfairDisplay(
                              color: config.primaryColorValue,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_editing)
                          IconButton(
                            key: V2AccountSettingsScreen.editButtonKey,
                            tooltip: LocalizationHelper.v2AccountEdit(context),
                            icon: Icon(
                              Icons.edit_outlined,
                              color: config.primaryColorValue,
                            ),
                            onPressed: state.hasProfile && !state.isLoading
                                ? _enterEditMode
                                : null,
                          ),
                      ],
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
                          if (_editing) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                key: V2AccountSettingsScreen.saveButtonKey,
                                onPressed: state.isSaving || state.isLoading
                                    ? null
                                    : _save,
                                child: state.isSaving
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                          semanticsLabel:
                                              LocalizationHelper.save(context),
                                        ),
                                      )
                                    : Text(LocalizationHelper.save(context)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
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
              Text(LocalizationHelper.v2AccountLoadFailed(context),
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
    final live = _liveErrors();
    final editable = !state.isSaving;
    final canPick = _editing && editable;
    final pickerStyle = OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      disabledForegroundColor: theme.colorScheme.onSurface,
      backgroundColor: _editing
          ? null
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
    );
    return KeyedSubtree(
      key: ValueKey('v2_account_form_$_formEpoch'),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (!_editing)
          const SizedBox.shrink()
        else if (state.phase == V2AccountPhase.validationError)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              LocalizationHelper.v2AccountFixFields(context),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          )
        else if (state.error != null &&
            state.phase == V2AccountPhase.apiError)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              LocalizationHelper.v2AccountSaveFailed(context),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        _Field(
          fieldKey: V2AccountSettingsScreen.usernameFieldKey,
          label: LocalizationHelper.v2AccountUsername(context),
          controller: _username,
          focusNode: _usernameFocus,
          editing: _editing,
          enabled: editable,
          error: _fieldError('username', live, fieldErrors),
          onChanged: (_) => _onFieldChanged('username'),
        ),
        _Field(
          fieldKey: V2AccountSettingsScreen.firstNameFieldKey,
          label: LocalizationHelper.v2AccountFirstName(context),
          controller: _firstName,
          focusNode: _firstNameFocus,
          editing: _editing,
          enabled: editable,
          error: _fieldError('firstName', live, fieldErrors),
          onChanged: (_) => _onFieldChanged('firstName'),
        ),
        _Field(
          fieldKey: V2AccountSettingsScreen.lastNameFieldKey,
          label: LocalizationHelper.v2AccountLastName(context),
          controller: _lastName,
          focusNode: _lastNameFocus,
          editing: _editing,
          enabled: editable,
          error: _fieldError('lastName', live, fieldErrors),
          onChanged: (_) => _onFieldChanged('lastName'),
        ),
        const SizedBox(height: 8),
        Text(LocalizationHelper.dateOfBirth(context),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OutlinedButton(
          key: const Key('v2_account_dob'),
          onPressed: canPick ? _pickDob : null,
          style: pickerStyle,
          child: Text(_dobDisplay()),
        ),
        if (_editing && fieldErrors['dateOfBirth'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage('dateOfBirth', fieldErrors['dateOfBirth']!),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        _Field(
          label: LocalizationHelper.v2AccountMobileNumber(context),
          controller: _mobile,
          focusNode: _mobileFocus,
          editing: _editing,
          enabled: editable,
          keyboardType: TextInputType.phone,
          error: _fieldError('mobileNumber', live, fieldErrors),
          onChanged: (_) => _onFieldChanged('mobileNumber'),
        ),
        _Field(
          label: LocalizationHelper.v2AccountCity(context),
          controller: _city,
          editing: _editing,
          enabled: editable,
          onChanged: (_) => _onFieldChanged('city'),
        ),
        const SizedBox(height: 8),
        Text(LocalizationHelper.regionCountry(context),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OutlinedButton(
          key: const Key('v2_account_country'),
          onPressed: canPick ? _openCountryPicker : null,
          style: pickerStyle,
          child: Row(
            children: [
              Expanded(child: Text(_countryLabel())),
              if (_editing && _controller.countriesLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_editing)
                const Icon(Icons.expand_more),
            ],
          ),
        ),
        if (_editing && fieldErrors['country'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage('country', fieldErrors['country']!),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        if (_editing && _controller.countriesError != null)
          TextButton(
            onPressed: _controller.loadCountries,
            child: Text(LocalizationHelper.v2AccountCountriesLoadFailed(context)),
          ),
      ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.focusNode,
    this.editing = true,
    this.enabled = true,
    this.error,
    this.onChanged,
    this.keyboardType,
  });

  final Key? fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;

  /// False in view mode: the field is disabled (not focusable) and styled
  /// as read-only.
  final bool editing;

  /// False while saving in edit mode: the field stays enabled but read-only.
  final bool enabled;
  final String? error;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: editing,
        readOnly: !enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: editing ? null : TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          filled: !editing,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: radius),
          disabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
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
              LocalizationHelper.selectCountry(context),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: LocalizationHelper.v2AccountSearchCountries(context),
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
                    child: Text(
                      LocalizationHelper.v2AccountCountriesLoadFailed(context),
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Text(LocalizationHelper.noResultsFound(context)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: Text(LocalizationHelper.clear(context)),
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
