import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/api_service.dart';
import '../../screens/auth/auth_screen.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final UserService _userService = UserService();

  final TextEditingController nickNameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  String? selectedCity;
  String? selectedCountry;
  bool _isLoading = false;
  bool _isLoadingProfile = true;

  final List<String> cities = ['Chennai', 'Coimbatore', 'Madurai', 'Salem'];
  final List<String> countries = ['India', 'USA', 'UK', 'Canada'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    nickNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  /// Load user profile data and bind to textfields
  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoadingProfile = true);

      // Check if API Service is initialized
      final apiService = ApiService();
      if (!apiService.isInitialized) {
        await apiService.initialize();
      }

      // Fetch user profile from API
      final response = await _profileService.getUserProfile();

      if (response.success && response.data != null) {
        // Response structure: {"message": "success", "data": {...userData...}}
        final responseMap = response.data as Map<String, dynamic>;
        final userData = responseMap['data'] as Map<String, dynamic>?;

        if (userData != null) {
          debugPrint('📦 Binding user data to fields:');
          debugPrint('   NickName: ${userData['nickName']}');
          debugPrint('   Email: ${userData['email']}');
          debugPrint('   FirstName: ${userData['firstName']}');
          _bindProfileDataToFields(userData);
        } else {
          debugPrint('⚠️ User data not found in response');
          // Fallback to local user data
          final localUserData = _userService.getUserData();
          if (localUserData != null) {
            _bindProfileDataToFields(localUserData);
          }
        }
      } else {
        debugPrint('⚠️ API call failed, using local user data');
        // Fallback to local user data if API call fails
        final localUserData = _userService.getUserData();
        if (localUserData != null) {
          _bindProfileDataToFields(localUserData);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
      // Fallback to local user data
      final localUserData = _userService.getUserData();
      if (localUserData != null) {
        _bindProfileDataToFields(localUserData);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  /// Bind profile data to textfields
  void _bindProfileDataToFields(Map<String, dynamic> userData) {
    if (!mounted) return;

    setState(() {
      nickNameController.text = userData['nickName']?.toString() ?? '';
      firstNameController.text = userData['firstName']?.toString() ?? '';
      lastNameController.text = userData['secondName']?.toString() ?? '';
      emailController.text = userData['email']?.toString() ?? '';
      mobileController.text = userData['mobileNumber']?.toString() ?? '';
      pincodeController.text = userData['pincode']?.toString() ?? '';
      selectedCity = userData['city']?.toString();
      selectedCountry = userData['country']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          body: SafeArea(
            child:
                _isLoadingProfile
                    ? Center(
                      child: CircularProgressIndicator(
                        color: config.primaryColorValue,
                      ),
                    )
                    : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          children: [
                            // Header
                            commonappBar(config.appNameLogo, () {
                              Navigator.pop(context);
                            }),
                            giveHeight(12),

                            // Title
                            Text(
                              LocalizationHelper.accountSettings(context),
                              style: GoogleFonts.playfairDisplay(
                                color: config.primaryColorValue,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            giveHeight(20),

                            // 🔹 User name section
                            _buildSectionTitle(
                              LocalizationHelper.userName(context),
                              theme,
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: 'Nickname *',
                              icon: Icons.person_outline,
                              controller: nickNameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nickname is required';
                                }
                                return null;
                              },
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: LocalizationHelper.enterYourFirstName(
                                context,
                              ),
                              icon: Icons.person_outline,
                              controller: firstNameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return LocalizationHelper.firstNameRequired(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: LocalizationHelper.enterYourSecondName(
                                context,
                              ),
                              icon: Icons.person_outline,
                              controller: lastNameController,
                            ),
                            giveHeight(16),
                            _buildButtonRow(context, config),
                            _divider(),

                            // 🔹 Email section
                            _buildSectionTitle(
                              LocalizationHelper.emailId(context),
                              theme,
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: LocalizationHelper.enterYourEmailId(
                                context,
                              ),
                              icon: Icons.email_outlined,
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return LocalizationHelper.emailRequired(
                                    context,
                                  );
                                }
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value)) {
                                  return LocalizationHelper.enterValidEmail(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(16),
                            _buildButtonRow(context, config),
                            _divider(),

                            // 🔹 Personal details
                            _buildSectionTitle(
                              LocalizationHelper.personalDetails(context),
                              theme,
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: LocalizationHelper.enterMobileNumber(
                                context,
                              ),
                              icon: Icons.phone_outlined,
                              prefixText: "+91",
                              controller: mobileController,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return LocalizationHelper.mobileNumberRequired(
                                    context,
                                  );
                                }
                                if (value.length < 10) {
                                  return LocalizationHelper.enterValidMobileNumber(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(10),
                            _buildDropdownField(
                              hint: LocalizationHelper.selectCity(context),
                              value: selectedCity,
                              items: cities,
                              onChanged:
                                  (value) =>
                                      setState(() => selectedCity = value),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return LocalizationHelper.pleaseSelectCity(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(10),
                            _buildInputField(
                              theme: theme,
                              label: LocalizationHelper.enterPincode(context),
                              controller: pincodeController,
                              icon: Icons.location_on_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return LocalizationHelper.pincodeRequired(
                                    context,
                                  );
                                }
                                if (value.length != 6) {
                                  return LocalizationHelper.enterValidPincode(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(10),
                            _buildDropdownField(
                              hint: LocalizationHelper.selectCountry(context),
                              value: selectedCountry,
                              items: countries,
                              onChanged:
                                  (value) =>
                                      setState(() => selectedCountry = value),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return LocalizationHelper.pleaseSelectCountry(
                                    context,
                                  );
                                }
                                return null;
                              },
                            ),
                            giveHeight(16),
                            _buildButtonRow(context, config),
                            _divider(),

                            // 🔹 Social Account
                            _buildSectionTitle(
                              LocalizationHelper.socialAccount(context),
                              theme,
                            ),
                            giveHeight(10),
                            _buildGoogleLoginButton(),
                            _divider(),

                            // 🔹 Logout button
                            _buildLogoutButton(config),
                          ],
                        ),
                      ),
                    ),
          ),
        );
      },
    );
  }

  // 🧩 Common Widgets

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: GoogleFonts.playfair(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.secondary,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    String? prefixText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: theme.colorScheme.secondary,
        ),
        prefixIcon:
            prefixText != null
                ? Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Text(
                    prefixText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: icon != null ? Icon(icon, color: Colors.red) : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black87, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.arrow_drop_down),
      validator: validator,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black87, width: 1),
        ),
      ),
      hint: Text(
        hint,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
      ),
      onChanged: onChanged,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    );
  }

  Widget _buildButtonRow(BuildContext context, dynamic config) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: config.primaryColorValue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child:
                _isLoading
                    ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      LocalizationHelper.save(context),
                      style: const TextStyle(color: Colors.white),
                    ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _handleCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              LocalizationHelper.cancel(context),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(color: Colors.grey[300], thickness: 1),
  );

  Widget _buildGoogleLoginButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/google_logo.png',
            height: 24,
            width: 24,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.g_mobiledata, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              LocalizationHelper.loginWithGoogle(context),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 4),
          Text(
            LocalizationHelper.connected(context),
            style: const TextStyle(color: Colors.green, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(dynamic config) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          height: 48,
          child: ElevatedButton(
            onPressed: _handleLogout,
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
      ),
    );
  }

  // 🧠 Logic Handlers
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationHelper.pleaseFixErrorsBeforeSaving(context),
            ),
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Check if API Service is initialized
      final apiService = ApiService();
      if (!apiService.isInitialized) {
        await apiService.initialize();
      }

      // Get user data to get category
      final userData = _userService.getUserData();
      final category = userData?['category'];

      // Call update profile API
      final response = await _profileService.updateProfile(
        nickName: nickNameController.text.trim(),
        email: emailController.text.trim(),
        firstName: firstNameController.text.trim(),
        secondName: lastNameController.text.trim(),
        personalDetails: {"nickName": firstNameController.text.trim()},
        mobileNumber: mobileController.text.trim(),
        city: selectedCity,
        pincode: pincodeController.text.trim(),
        country: selectedCountry,
        category: category,
      );

      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationHelper.formSubmittedSuccessfully(context),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    _formKey.currentState!.reset();
    nickNameController.clear();
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    mobileController.clear();
    pincodeController.clear();
    setState(() {
      selectedCity = null;
      selectedCountry = null;
    });
    // Reload profile data to restore original values
    _loadUserProfile();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) {
        return showLogoutModalBottomSheet(context);
      },
    );

    if (shouldLogout == true) {
      try {
        setState(() => _isLoading = true);

        // Check if API Service is initialized
        final apiService = ApiService();
        if (!apiService.isInitialized) {
          await apiService.initialize();
        }

        // Call logout API
        final response = await _profileService.logout();

        if (mounted) {
          if (response.success) {
            // Navigate to auth screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
              (route) => false,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.error ?? 'Failed to logout'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error logging out: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
