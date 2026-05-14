import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity and trigger background refresh
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = true;
  final List<VoidCallback> _onOnlineCallbacks = [];
  final List<VoidCallback> _onOfflineCallbacks = [];

  bool get isOnline => _isOnline;

  /// Initialize network monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline =
        results.any((r) => r != ConnectivityResult.none);
    debugPrint('🌐 Network status: ${_isOnline ? "Online" : "Offline"}');

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline =
            results.any((r) => r != ConnectivityResult.none);
        
        debugPrint('🌐 Network status changed: ${_isOnline ? "Online" : "Offline"}');

        // Trigger callbacks
        if (!wasOnline && _isOnline) {
          // Just came online - trigger refresh callbacks
          debugPrint('🔄 Network came online - triggering refresh callbacks');
          for (final callback in _onOnlineCallbacks) {
            try {
              callback();
            } catch (e) {
              debugPrint('❌ Error in onOnline callback: $e');
            }
          }
        } else if (wasOnline && !_isOnline) {
          // Just went offline
          debugPrint('📴 Network went offline');
          for (final callback in _onOfflineCallbacks) {
            try {
              callback();
            } catch (e) {
              debugPrint('❌ Error in onOffline callback: $e');
            }
          }
        }
      },
    );
  }

  /// Register callback for when network comes online
  void onOnline(VoidCallback callback) {
    _onOnlineCallbacks.add(callback);
  }

  /// Register callback for when network goes offline
  void onOffline(VoidCallback callback) {
    _onOfflineCallbacks.add(callback);
  }

  /// Remove callback
  void removeOnOnlineCallback(VoidCallback callback) {
    _onOnlineCallbacks.remove(callback);
  }

  /// Remove callback
  void removeOnOfflineCallback(VoidCallback callback) {
    _onOfflineCallbacks.remove(callback);
  }

  /// Check if device has internet connection
  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline =
          results.any((r) => r != ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _onOnlineCallbacks.clear();
    _onOfflineCallbacks.clear();
  }
}

