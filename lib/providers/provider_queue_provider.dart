import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import '../repositories/repositories.dart';
import 'provider_support.dart';

// The signed-in provider's queue and the actions on it.
class ProviderQueueProvider extends ChangeNotifier with SafeNotifier {
  ProviderQueueProvider(this._repository);

  final QueueRepository _repository;
  StreamSubscription<ServiceQueue?>? _queueSubscription;
  StreamSubscription<List<QueueEntry>>? _entriesSubscription;
  AppUser? _user;
  ServiceQueue? _queue;
  String? _watchedQueueId;
  List<QueueEntry> _entries = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _loadError;
  bool _isBusy = false;
  String? _actionError;

  LoadStatus get status => _status;
  String? get loadError => _loadError;
  bool get isBusy => _isBusy;
  String? get actionError => _actionError;

  ServiceQueue? get queue => _queue;
  List<QueueEntry> get activeEntries => QueueRules.activeEntries(_entries);
  List<QueueEntry> get waitingEntries => QueueRules.waitingEntries(_entries);
  QueueEntry? get calledEntry => QueueRules.calledEntry(_entries);

  bool get canCallNext => !_isBusy && QueueRules.checkCallNext(_entries).isOk;
  bool get canFinishCalled =>
      !_isBusy && QueueRules.checkFinishCalled(_entries).isOk;

  // Called by the app when the signed-in user changes. A new user never sees
  // the queue that belongs to the previous one.
  void bindUser(AppUser? user) {
    if (user?.id == _user?.id) return;
    _user = user;
    _cancelAll();
    _queue = null;
    _entries = const [];
    _status = LoadStatus.loading;
    _loadError = null;
    _actionError = null;
    _isBusy = false;
    if (user != null && user.role == UserRole.provider) {
      final id = user.id;
      scheduleMicrotask(() {
        if (_user?.id == id) _subscribe();
      });
    }
    scheduleMicrotask(notifyListeners);
  }

  void retry() {
    if (_user == null) return;
    _cancelAll();
    _status = LoadStatus.loading;
    _loadError = null;
    notifyListeners();
    _subscribe();
  }

  Future<OperationResult> createQueue({
    required String name,
    required String description,
    required int averageServiceMinutes,
  }) => _run(
    (user) => _repository.createQueue(
      provider: user,
      name: name,
      description: description,
      averageServiceMinutes: averageServiceMinutes,
    ),
  );

  Future<OperationResult> callNext() => _runOnQueue(
    (user, queue) => _repository.callNext(provider: user, queueId: queue.id),
  );

  Future<OperationResult> markServed() => _runOnQueue(
    (user, queue) => _repository.finishCalled(
      provider: user,
      queueId: queue.id,
      outcome: MembershipStatus.served,
    ),
  );

  Future<OperationResult> skipCalled() => _runOnQueue(
    (user, queue) => _repository.finishCalled(
      provider: user,
      queueId: queue.id,
      outcome: MembershipStatus.skipped,
    ),
  );

  Future<OperationResult> _runOnQueue(
    Future<OperationResult> Function(AppUser user, ServiceQueue queue) action,
  ) {
    final queue = _queue;
    if (queue == null) {
      return Future.value(
        OperationResult.failure(OperationError.queueNotFound),
      );
    }
    return _run((user) => action(user, queue));
  }

  Future<OperationResult> _run(
    Future<OperationResult> Function(AppUser user) action,
  ) async {
    final user = _user;
    if (user == null) {
      return OperationResult.failure(OperationError.notSignedIn);
    }
    if (_isBusy) return OperationResult.failure(OperationError.busy);
    _isBusy = true;
    _actionError = null;
    notifyListeners();
    OperationResult result;
    try {
      result = await action(user);
    } catch (_) {
      result = OperationResult.failure(OperationError.failed);
    }
    _isBusy = false;
    _actionError = result.message;
    notifyListeners();
    return result;
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }

  void _subscribe() {
    final user = _user;
    if (user == null) return;
    _queueSubscription = _repository
        .watchQueueOfProvider(user.id)
        .listen(_onQueue, onError: _onError);
  }

  void _onQueue(ServiceQueue? queue) {
    _queue = queue;
    _status = LoadStatus.ready;
    _loadError = null;
    if (queue == null) {
      _entriesSubscription?.cancel();
      _entriesSubscription = null;
      _watchedQueueId = null;
      _entries = const [];
    } else if (_watchedQueueId != queue.id) {
      _entriesSubscription?.cancel();
      _watchedQueueId = queue.id;
      _entriesSubscription = _repository
          .watchEntries(queue.id)
          .listen(_onEntries, onError: _onError);
    }
    notifyListeners();
  }

  void _onEntries(List<QueueEntry> entries) {
    _entries = entries;
    notifyListeners();
  }

  void _onError(Object error, StackTrace stackTrace) {
    _status = LoadStatus.error;
    _loadError = 'Could not load your queue. Check your connection and retry.';
    notifyListeners();
  }

  void _cancelAll() {
    _queueSubscription?.cancel();
    _queueSubscription = null;
    _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _watchedQueueId = null;
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }
}