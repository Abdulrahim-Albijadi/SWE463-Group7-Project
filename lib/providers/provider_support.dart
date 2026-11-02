import 'package:flutter/foundation.dart';

enum LoadStatus { loading, ready, error }

// Stops a Provider from notifying after it was disposed.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}