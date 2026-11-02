import 'dart:async';

import 'package:flutter/foundation.dart';
import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import '../repositories/repositories.dart';
import 'provider_support.dart';

enum AuthStatus { initializing, signedOut, signedIn }

class AuthProvider extends ChangeNotifier with SafeNotifier {
  AuthProvider(this._repository) {
    _subscription = _repository.authStateChanges().listen(
      _onUserChanged,
      onError: (Object error, StackTrace stackTrace) {
        _status = AuthStatus.signedOut;
        _error = OperationResult.failure(OperationError.failed).message;
        notifyListeners();
      },
    );
  }

  final AuthRepository _repository;
  StreamSubscription<AppUser?>? _subscription;
  AppUser? _currentUser;
  AuthStatus _status = AuthStatus.initializing;
  bool _isBusy = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isBusy => _isBusy;
  String? get error => _error;

  void _onUserChanged(AppUser? user) {
    _currentUser = user;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) => _run(() => _repository.signIn(email: email, password: password));

  Future<AuthOutcome> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) => _run(
    () => _repository.register(
      name: name,
      email: email,
      password: password,
      role: role,
    ),
  );

  Future<AuthOutcome> _run(Future<AuthOutcome> Function() action) async {
    if (_isBusy) {
      return AuthOutcome(OperationResult.failure(OperationError.busy));
    }
    _isBusy = true;
    _error = null;
    notifyListeners();
    AuthOutcome outcome;
    try {
      outcome = await action();
    } catch (_) {
      outcome = AuthOutcome(OperationResult.failure(OperationError.failed));
    }
    _isBusy = false;
    _error = outcome.result.message;
    if (outcome.isOk) {
      _currentUser = outcome.user;
      _status = AuthStatus.signedIn;
    }
    notifyListeners();
    return outcome;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _currentUser = null;
    _status = AuthStatus.signedOut;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}