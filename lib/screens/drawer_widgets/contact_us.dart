import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    onTap: items[i].onTap,
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
      final email = config.contactEmail.trim();
      items.add(
        _ContactItemData(
          icon: Icons.email_outlined,
          title: LocalizationHelper.emailText(context),
          value: email,
          onTap: () => _launchEmail(context, email),
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
      final website = config.contactWebsite.trim();
      items.add(
        _ContactItemData(
          icon: Icons.language,
          title: LocalizationHelper.websiteText(context),
          value: website,
          onTap: () => _launchWebsite(context, website),
        ),
      );
    }

    return items;
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: trimmed,
    );
    await _launchExternalUri(context, uri);
  }

  Future<void> _launchWebsite(BuildContext context, String website) async {
    final normalized = _normalizeWebsiteUrl(website);
    if (normalized == null) {
      return;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return;
    }

    await _launchExternalUri(context, uri);
  }

  /// Ensures a scheme for bare domains without creating `https://https://...`.
  String? _normalizeWebsiteUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }

    return 'https://$trimmed';
  }

  Future<void> _launchExternalUri(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open link')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error launching contact URI: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open link')),
        );
      }
    }
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    final row = Row(
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

    if (onTap == null) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

class _ContactItemData {
  const _ContactItemData({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
}
