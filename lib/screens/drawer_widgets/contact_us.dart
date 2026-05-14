import 'package:flutter/material.dart';
import '../../core/utils/localization_helper.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              LocalizationHelper.contactSupportText(context),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildContactItem(
              icon: Icons.email_outlined,
              title: LocalizationHelper.emailText(context),
              subtitle: 'newson2025@gmail.com',
              theme: theme,
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              icon: Icons.phone_outlined,
              title: LocalizationHelper.phoneText(context),
              subtitle: '+91 99442 77553',
              theme: theme,
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              icon: Icons.language,
              title: LocalizationHelper.websiteText(context),
              subtitle: 'www.newson.app',
              theme: theme,
            ),
          ],
        ),
      ),
    );
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
        Column(
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
      ],
    );
  }
}
