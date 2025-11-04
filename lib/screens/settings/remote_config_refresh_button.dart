import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/remote_config_provider.dart';

/// A button widget to manually refresh Remote Config
class RemoteConfigRefreshButton extends StatefulWidget {
  const RemoteConfigRefreshButton({super.key});

  @override
  State<RemoteConfigRefreshButton> createState() => _RemoteConfigRefreshButtonState();
}

class _RemoteConfigRefreshButtonState extends State<RemoteConfigRefreshButton> {
  bool _isRefreshing = false;

  Future<void> _refreshConfig() async {
    setState(() => _isRefreshing = true);
    
    try {
      final configProvider = Provider.of<RemoteConfigProvider>(context, listen: false);
      await configProvider.refresh();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Remote Config refreshed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to refresh: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      onPressed: _isRefreshing ? null : _refreshConfig,
      tooltip: 'Refresh Remote Config',
    );
  }
}
