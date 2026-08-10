import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/localization_helper.dart';
import '../../data/models/remote_config_model.dart';
import '../../providers/remote_config_provider.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, _) {
        final config = configProvider.config;
        final items = _visibleContactItems(context, config);

        return Scaffold(
          appBar: AppBar(
            title: Text(LocalizationHelper.contactUs(context)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationHelper.getInTouch(context),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  LocalizationHelper.contactSupportText(context),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _buildContactItem(
                    icon: items[i].icon,
                    title: items[i].title,
                    subtitle: items[i].value,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ContactItemData> _visibleContactItems(
    BuildContext context,
    RemoteConfigModel config,
  ) {
    final items = <_ContactItemData>[];

    if (config.contactEmailVisible && config.contactEmail.trim().isNotEmpty) {
      items.add(
        _ContactItemData(
          icon: Icons.email_outlined,
          title: LocalizationHelper.emailText(context),
          value: config.contactEmail.trim(),
        ),
      );
    }
    if (config.contactPhoneVisible && config.contactPhone.trim().isNotEmpty) {
      items.add(
        _ContactItemData(
          icon: Icons.phone_outlined,
          title: LocalizationHelper.phoneText(context),
          value: config.contactPhone.trim(),
        ),
      );
    }
    if (config.contactWebsiteVisible &&
        config.contactWebsite.trim().isNotEmpty) {
      items.add(
        _ContactItemData(
          icon: Icons.language,
          title: LocalizationHelper.websiteText(context),
          value: config.contactWebsite.trim(),
        ),
      );
    }

    return items;
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactItemData {
  const _ContactItemData({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}
