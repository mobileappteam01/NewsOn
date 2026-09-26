// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:newson/core/navigation/app_navigator.dart';
import 'package:newson/core/utils/auth_navigation_helper.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/data/services/user_service.dart';
import 'package:newson/screens/category_selection/category_selection_screen.dart';
import 'package:newson/screens/drawer_widgets/account_settings.dart';
import 'package:newson/screens/drawer_widgets/application_settings.dart';
import 'package:newson/screens/drawer_widgets/bookmark.dart';
import 'package:newson/screens/drawer_widgets/privacy_policy.dart';
import 'package:newson/screens/drawer_widgets/terms_and_conditions.dart';
import 'package:newson/screens/drawer_widgets/contact_us.dart';
import 'package:newson/screens/home/tabs/news_feed_tab_new.dart';
import 'package:provider/provider.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import 'package:newson/features/account/presentation/v2_account_settings_screen.dart';
import 'package:newson/features/home_v2/domain/v2_effective_categories.dart';
import 'package:newson/features/notifications/presentation/v2_notification_inbox_screen.dart';
import 'package:newson/screens/drawer_widgets/notification.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    showImage(
                      config.getAppNameLogoForTheme(theme.brightness),
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
                          title: LocalizationHelper.getDrawerMenuTitle(
                            context,
                            i,
                          ),
                          onTap: () async {
                            // Account Settings (0) and Bookmarks (2) need login.
                            final needsLogin =
                                (i == 0 || i == 2) && !UserService().isLoggedIn;
                            Navigator.pop(context); // Close the drawer first
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );
                            if (needsLogin) {
                              navigateToLoginForAccountFeatureGlobal();
                              return;
                            }
                            final navigator = appNavigatorKey.currentState;
                            if (navigator == null) return;

                            final Widget page;
                            if (i == 0) {
                              final useV2Account =
                                  V2FeatureFlags.homeReader(config) ||
                                      V2FeatureFlags.notifications(config);
                              page = useV2Account
                                  ? const V2AccountSettingsScreen()
                                  : const AccountSettings();
                            } else if (i == 1) {
                              final useV2Inbox =
                                  V2FeatureFlags.homeReader(config) ||
                                      V2FeatureFlags.notifications(config);
                              page = useV2Inbox
                                  ? const V2NotificationInboxScreen()
                                  : const NotificationView();
                            } else if (i == 2) {
                              page = BookMark();
                            } else if (i == 3) {
                              page = ApplicationSettings();
                            } else if (i == 4) {
                              page = TermsAndConditions();
                            } else if (i == 5) {
                              page = PrivacyPolicy();
                            } else {
                              final useV2Categories =
                                  V2FeatureFlags.homeReader(config) ||
                                      V2FeatureFlags.notifications(config);
                              page = CategorySelectionScreen(
                                isFromSideMenu: true,
                                useV2Catalog: useV2Categories,
                              );
                            }

                            final result = await navigator.push(
                              MaterialPageRoute(builder: (_) => page),
                            );

                            // Refresh Home category chips after successful prefs update.
                            if (page is CategorySelectionScreen &&
                                result == true) {
                              NewsFeedTabNew
                                  .preferredCategoriesRevision.value++;
                              V2CategoryPreferenceResolver.bump();
                            }
                          },
                          iconColor: config.primaryColorValue,
                        ),
                      _buildMenuItem(
                        context,
                        icon: Icons.contact_support_outlined,
                        title: LocalizationHelper.contactUs(context),
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(
                            const Duration(milliseconds: 200),
                            () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (c) => const ContactUsScreen(),
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
                    '${LocalizationHelper.version(context)} 1.0.0',
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
      builder: (context) => AlertDialog(
        title: Text(LocalizationHelper.selectLanguage(context)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languageProvider.languageNames.length,
            itemBuilder: (context, index) {
              final languageName = languageProvider.languageNames[index];

              return RadioListTile<String>(
                title: Text(
                  languageName,
                ), // Display full language name (English, Tamil, Hindi)
                value: languageName,
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
            child: Text(LocalizationHelper.cancel(context)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${LocalizationHelper.version(context)}: 1.0.0'),
            const SizedBox(height: 8),
            Text(
              LocalizationHelper.yourPersonalizedNewsApplication(context),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 NewsOn. All rights reserved.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocalizationHelper.close(context)),
          ),
        ],
      ),
    );
  }
}
