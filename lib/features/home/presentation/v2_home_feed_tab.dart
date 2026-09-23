import 'package:flutter/material.dart';

import 'v2_home_screen.dart';

/// Thin keep-alive shell so [home_screen] can swap V1/V2 without growing V1.
///
/// All Home experience lives in [V2HomeScreen] under `lib/features/home/`.
class V2HomeFeedTab extends StatefulWidget {
  const V2HomeFeedTab({
    super.key,
    this.onOpenForYouTab,
  });

  final VoidCallback? onOpenForYouTab;

  @override
  State<V2HomeFeedTab> createState() => _V2HomeFeedTabState();
}

class _V2HomeFeedTabState extends State<V2HomeFeedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return V2HomeScreen(
      onOpenForYouTab: widget.onOpenForYouTab,
    );
  }
}
