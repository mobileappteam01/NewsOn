import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';

class TermsAndConditions extends StatefulWidget {
  const TermsAndConditions({super.key});

  @override
  State<TermsAndConditions> createState() => _TermsAndConditionsState();
}

class _TermsAndConditionsState extends State<TermsAndConditions> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        return Scaffold(
          body: ListView(
            children: [
              commonappBar(config.appNameLogo, () {
                Navigator.pop(context);
              }),
              giveHeight(12),
              Text(
                LocalizationHelper.termsAndConditions(context),
                style: GoogleFonts.playfairDisplay(
                  color: config.primaryColorValue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
