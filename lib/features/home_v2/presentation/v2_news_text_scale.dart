import 'package:flutter/widgets.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/storage_service.dart';

/// One text-size source for V2 Home, Reader, and Article Detail.
///
/// Settings writes [AppConstants.textSizeKey]. These screens listen here
/// instead of keeping their own font-size state.
class V2NewsTextScale extends ChangeNotifier {
  V2NewsTextScale._();

  static final V2NewsTextScale instance = V2NewsTextScale._();

  double _size = AppConstants.defaultTextSize;
  bool _loaded = false;

  double get size {
    _ensureLoaded();
    return _size;
  }

  /// Multiplier against [AppConstants.defaultTextSize].
  double get factor {
    const base = AppConstants.defaultTextSize;
    if (base <= 0) return 1;
    return size / base;
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = StorageService.getSetting(
        AppConstants.textSizeKey,
        defaultValue: AppConstants.defaultTextSize,
      );
      if (saved is double && saved > 0) {
        _size = saved;
      } else if (saved is num && saved > 0) {
        _size = saved.toDouble();
      }
    } catch (_) {
      _size = AppConstants.defaultTextSize;
    }
  }

  /// Updates the shared size after Settings persists it.
  void apply(double size) {
    if (size <= 0 || size == _size) {
      _loaded = true;
      return;
    }
    _size = size;
    _loaded = true;
    notifyListeners();
  }

  @visibleForTesting
  void debugReset(double size) {
    _size = size;
    _loaded = true;
    notifyListeners();
  }
}

/// Scales news text in [child]. Does not wrap app chrome.
class V2NewsTextScope extends StatelessWidget {
  const V2NewsTextScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: V2NewsTextScale.instance,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(V2NewsTextScale.instance.factor),
          ),
          child: child!,
        );
      },
      child: child,
    );
  }
}
