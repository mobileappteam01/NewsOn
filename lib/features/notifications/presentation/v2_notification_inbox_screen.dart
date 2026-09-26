import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/localization_helper.dart';
import '../../../core/utils/shared_functions.dart';
import '../../../providers/remote_config_provider.dart';
import '../data/notification_inbox_api.dart';
import '../domain/notification_inbox_state.dart';

/// V2 Side Menu → Notifications inbox with loading / empty / error / list.
class V2NotificationInboxScreen extends StatefulWidget {
  const V2NotificationInboxScreen({
    super.key,
    this.controller,
  });

  @visibleForTesting
  final V2NotificationInboxController? controller;

  @override
  State<V2NotificationInboxScreen> createState() =>
      _V2NotificationInboxScreenState();
}

class _V2NotificationInboxScreenState extends State<V2NotificationInboxScreen> {
  late final V2NotificationInboxController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? V2NotificationInboxController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, _) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final state = _controller.state;
                return RefreshIndicator(
                  onRefresh: _controller.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              commonappBar(
                                config.getAppNameLogoForTheme(theme.brightness),
                                () => Navigator.pop(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                LocalizationHelper.notifications(context),
                                style: GoogleFonts.playfairDisplay(
                                  color: config.primaryColorValue,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      ..._sliversFor(state, theme),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sliversFor(V2NotificationInboxState state, ThemeData theme) {
    switch (state.phase) {
      case V2NotificationInboxPhase.loading:
        return [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ];
      case V2NotificationInboxPhase.empty:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyNotifications(theme: theme),
          ),
        ];
      case V2NotificationInboxPhase.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorNotifications(
              theme: theme,
              message: state.error ?? 'Could not load notifications',
              onRetry: _controller.loadInitial,
            ),
          ),
        ];
      case V2NotificationInboxPhase.withData:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = state.items[index];
                  return _NotificationTile(item: item, theme: theme);
                },
                childCount: state.items.length,
              ),
            ),
          ),
        ];
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: theme.colorScheme.outline.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When NewsOn has updates for you, they will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotifications extends StatelessWidget {
  const _ErrorNotifications({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  final ThemeData theme;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(LocalizationHelper.retry(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.theme});

  final V2NotificationInboxItem item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(
          item.isRead
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          item.title,
          style: GoogleFonts.inter(
            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: item.message.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
