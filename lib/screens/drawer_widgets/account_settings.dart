import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../providers/remote_config_provider.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  String? selectedCity;
  String? selectedCountry;

  final List<String> cities = ['Chennai', 'Coimbatore', 'Madurai', 'Salem'];
  final List<String> countries = ['India', 'USA', 'UK', 'Canada'];

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    pincodeController.dispose();
    super.dispose();
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
            child: Padding(
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
                      "Account settings",
                      style: GoogleFonts.playfairDisplay(
                        color: config.primaryColorValue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    giveHeight(20),

                    // 🔹 User name section
                    _buildSectionTitle("User name", theme),
                    giveHeight(10),
                    _buildInputField(
                      theme: theme,
                      label: "Enter Your First Name *",
                      icon: Icons.person_outline,
                      controller: firstNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "First name is required";
                        }
                        return null;
                      },
                    ),
                    giveHeight(10),
                    _buildInputField(
                      theme: theme,
                      label: "Enter Your Second Name",
                      icon: Icons.person_outline,
                      controller: lastNameController,
                    ),
                    giveHeight(16),
                    _buildButtonRow(context, config),
                    _divider(),

                    // 🔹 Email section
                    _buildSectionTitle("Email-ID", theme),
                    giveHeight(10),
                    _buildInputField(
                      theme: theme,
                      label: "Enter Your Email ID",
                      icon: Icons.email_outlined,
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Email is required";
                        }
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    giveHeight(16),
                    _buildButtonRow(context, config),
                    _divider(),

                    // 🔹 Personal details
                    _buildSectionTitle("Personal details", theme),
                    giveHeight(10),
                    _buildInputField(
                      theme: theme,
                      label: "Enter mobile number",
                      icon: Icons.phone_outlined,
                      prefixText: "+91",
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Mobile number is required";
                        }
                        if (value.length < 10) {
                          return "Enter a valid 10-digit mobile number";
                        }
                        return null;
                      },
                    ),
                    giveHeight(10),
                    _buildDropdownField(
                      hint: "Select City",
                      value: selectedCity,
                      items: cities,
                      onChanged:
                          (value) => setState(() => selectedCity = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please select a city";
                        }
                        return null;
                      },
                    ),
                    giveHeight(10),
                    _buildInputField(
                      theme: theme,
                      label: "Enter Pincode",
                      controller: pincodeController,
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Pincode is required";
                        }
                        if (value.length != 6) {
                          return "Enter a valid 6-digit pincode";
                        }
                        return null;
                      },
                    ),
                    giveHeight(10),
                    _buildDropdownField(
                      hint: "Select Country",
                      value: selectedCountry,
                      items: countries,
                      onChanged:
                          (value) => setState(() => selectedCountry = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please select a country";
                        }
                        return null;
                      },
                    ),
                    giveHeight(16),
                    _buildButtonRow(context, config),
                    _divider(),

                    // 🔹 Social Account
                    _buildSectionTitle("Social account", theme),
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
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: config.primaryColorValue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
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
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
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
          const Expanded(
            child: Text(
              "Login with Google",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 4),
          const Text(
            "Connected",
            style: TextStyle(color: Colors.green, fontSize: 13),
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
            child: const Text(
              "Logout",
              style: TextStyle(
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
  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Form submitted successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fix errors before saving")),
      );
    }
  }

  void _handleCancel() {
    _formKey.currentState!.reset();
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    mobileController.clear();
    pincodeController.clear();
    setState(() {
      selectedCity = null;
      selectedCountry = null;
    });
  }

  void _handleLogout() {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        return showLogoutModalBottomSheet(context);
      },
    );
  }
}
