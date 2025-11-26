import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/remote_config_provider.dart';
import '../utils/shared_functions.dart';

/// Widget to display the dynamic app icon from Firebase Realtime Database
/// This can be used anywhere in the app to show the app icon
class DynamicAppIcon extends StatelessWidget {
  final double? size;
  final BoxFit fit;
  final double? width;
  final double? height;

  const DynamicAppIcon({
    super.key,
    this.size,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final appIconUrl = configProvider.config.appIcon;

        if (appIconUrl == null || appIconUrl.isEmpty) {
          // Fallback to default icon if app icon is not available
          return Icon(
            Icons.apps,
            size: size ?? 48,
            color: Theme.of(context).colorScheme.primary,
          );
        }

        // Display the dynamic app icon from Firebase
        return showImage(
          appIconUrl,
          fit,
          width: width ?? size,
          height: height ?? size,
        );
      },
    );
  }
}

