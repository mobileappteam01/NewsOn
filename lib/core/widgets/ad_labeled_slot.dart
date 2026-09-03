import 'package:flutter/material.dart';

import 'dailyhunt_ad_frame.dart';

/// Wraps an ad unit with a Dailyhunt-style "Ad" label frame.
class AdLabeledSlot extends StatelessWidget {
  const AdLabeledSlot({
    super.key,
    required this.child,
    this.label,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final Widget child;
  final String? label;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return DailyhuntAdFrame(
      label: label,
      margin: margin,
      child: child,
    );
  }
}
