// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:newson/screens/category_selection/category_selection_screen.dart';
import 'package:newson/screens/drawer_widgets/account_settings.dart';
import 'package:newson/screens/drawer_widgets/application_settings.dart';
import 'package:newson/screens/drawer_widgets/bookmark.dart';
import 'package:newson/screens/drawer_widgets/privacy_policy.dart';
import 'package:newson/screens/drawer_widgets/terms_and_conditions.dart';
import 'package:provider/provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../screens/drawer_widgets/notification.dart';
import '../utils/shared_functions.dart';

/// App drawer/sidebar menu
class AppDrawer extends StatelessWidget {
  final Function(int)? onNavigate;

  const AppDrawer({super.key, this.onNavigate});

  @override
  IconData getIconFromString(String? iconName) {
    switch (iconName) {
      case 'Icons.lock_outline':
        return Icons.lock_outline;
      case 'Icons.notifications':
        return Icons.notifications;
      case 'Icons.bookmark_border':
        return Icons.bookmark_border;
      case 'Icons.settings':
        return Icons.settings;
      case 'Icons.description_outlined':
        return Icons.description_outlined;
      case 'Icons.privacy_tip_outlined':
        return Icons.privacy_tip_outlined;
      case 'Icons.list_alt_outlined':
        return Icons.list_alt_outlined;
      case 'Icons.logout':
        return Icons.logout;
      default:
        return Icons.help_outline; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Provider.of<ThemeProvider>(context);
    Provider.of<LanguageProvider>(context);

    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        return Drawer(
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    showImage(
                      config.appNameLogo,
                      BoxFit.contain,
                      height: 60,
                      width: 80,
                    ),
                  ],
                ),

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (int i = 0; i < config.drawerMenu.length; i++)
                        _buildMenuItem(
                          context,
                          icon: getIconFromString(config.drawerMenu[i]['icon']),
                          title: config.drawerMenu[i]['title'].toString(),
                          onTap: () {
                            Navigator.pop(context); // Close the drawer first
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (c) =>
                                            i == 0
                                                ? const AccountSettings()
                                                : i == 1
                                                ? const NotificationView()
                                                : i == 2
                                                ? BookMark()
                                                : i == 3
                                                ? ApplicationSettings()
                                                : i == 4
                                                ? TermsAndConditions()
                                                : i == 5
                                                ? PrivacyPolicy()
                                                : CategorySelectionScreen(),
                                  ),
                                );
                              },
                            );
                          },
                          iconColor: config.primaryColorValue,
                        ),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Language'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languageProvider.supportedLanguages.length,
                itemBuilder: (context, index) {
                  final language = languageProvider.supportedLanguages[index];

                  return RadioListTile<String>(
                    title: Text(language),
                    value: language,
                    groupValue: languageProvider.selectedLanguage,
                    activeColor: const Color(0xFFE31E24),
                    onChanged: (value) {
                      if (value != null) {
                        languageProvider.setLanguage(value);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE31E24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEWS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'ON',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: 1.0.0'),
                SizedBox(height: 8),
                Text('Your personalized news application'),
                SizedBox(height: 16),
                Text(
                  '© 2025 NewsOn. All rights reserved.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
