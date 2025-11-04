// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/remote_config_provider.dart';

showRefreshButton() {
  return Consumer<RemoteConfigProvider>(
    builder: (context, configProvider, child) {
      final config = configProvider.config;
      final primaryColor = config.primaryColorValue;
      
      return Positioned(
        top: 16,
        right: 16,
        child: FloatingActionButton.small(
          backgroundColor: primaryColor,
          onPressed: () async {
            await configProvider.forceRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 Config refreshed! Check console logs'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      );
    },
  );
}

giveHeight(int value){
  return SizedBox(
    height: value.toDouble(),
  );
}
giveWidth(int value){
  return SizedBox(
    width: value.toDouble(),
  );
}
