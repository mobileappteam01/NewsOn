import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/remote_config_provider.dart';

class HeadLinesView extends StatefulWidget {
  const HeadLinesView({super.key});

  @override
  State<HeadLinesView> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<HeadLinesView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final primaryColor = config.primaryColorValue;
        final theme = Theme.of(context);

        final isDark = theme.brightness == Brightness.dark;
        debugPrint(
          "Dark secondary color: ${Theme.of(context).colorScheme.secondary} and $isDark",
        );
        return Container(child: ListView(children: [Row(children: [
                  
                ],
              )]));
      },
    );
  }
}
