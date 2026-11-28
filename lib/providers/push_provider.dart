import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/queue_data.dart';
import '../repositories/repositories.dart';
import '../services/push_service.dart';
import 'provider_support.dart';

enum PushStatus { idle, requesting, enabled, denied, unavailable, error }

// Registers the signed-in customer's device for push notifications: asks for
// permission, reads the device token and saves it on the customer's account,
// where the notification sender reads it. Providers (the role) do not receive
// notifications. When the account changes or signs out, this device's token is
// invalidated so the next user of the device never receives the previous
// user's messages. The messages themselves are sent by the Cloud Function in
// functions/; the in-app banners still come from MembershipProvider.alerts.
class PushProvider extends ChangeNotifier with SafeNotifier {
  PushProvider(this._push, this._accounts);

  final PushService _push;
  final AuthRepository _accounts;
  StreamSubscription<String>? _refreshSubscription;
  Future<void>? _forgetting;
  AppUser? _user;
  PushStatus _status = PushStatus.idle;

  PushStatus get status => _status;

  // Called by the app when the signed-in user changes.
  void bindUser(AppUser? user) {
    if (user?.id == _user?.id) return;
    final hadUser = _user != null;
    _user = user;
    _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _status = PushStatus.idle;
    if (hadUser) {
      _forgetting = _push.deleteToken().catchError((Object _) {});
    }
    if (user != null && user.role == UserRole.customer) {
      final id = user.id;
      scheduleMicrotask(() {
        if (_user?.id == id) _register(user);
      });
    }
    scheduleMicrotask(notifyListeners);
  }

  // Tries again after a failure or after the user changed the permission.
  void retry() {
    final user = _user;
    if (user == null || user.role != UserRole.customer) return;
    if (_status == PushStatus.requesting) return;
    _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _register(user);
  }

  bool _isCurrent(AppUser user) => _user?.id == user.id;

  Future<void> _register(AppUser user) async {
    _status = PushStatus.requesting;
    notifyListeners();
    try {
      // The previous account's token must be gone before a new one is read.
      await _forgetting;
      final permission = await _push.requestPermission();
      if (!_isCurrent(user)) return;
      if (permission != PushPermission.granted) {
        _status = permission == PushPermission.denied
            ? PushStatus.denied
            : PushStatus.unavailable;
        notifyListeners();
        return;
      }
      final token = await _push.getToken();
      if (!_isCurrent(user)) return;
      if (token == null) {
        _status = PushStatus.error;
        notifyListeners();
        return;
      }
      await _accounts.saveDeviceToken(user.id, token);
      if (!_isCurrent(user)) return;
      _refreshSubscription = _push.onTokenRefresh.listen(
        (newToken) => _saveRefreshed(user, newToken),
        onError: (Object error, StackTrace stackTrace) {
          if (!_isCurrent(user)) return;
          _status = PushStatus.error;
          notifyListeners();
        },
      );
      _status = PushStatus.enabled;
      notifyListeners();
    } catch (_) {
      if (!_isCurrent(user)) return;
      _status = PushStatus.error;
      notifyListeners();
    }
  }

  Future<void> _saveRefreshed(AppUser user, String token) async {
    try {
      if (_isCurrent(user)) await _accounts.saveDeviceToken(user.id, token);
    } catch (_) {
      if (!_isCurrent(user)) return;
      _status = PushStatus.error;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }
}
