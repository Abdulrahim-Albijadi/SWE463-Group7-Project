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
  bool _queueLoaded = false;
  bool _entriesLoaded = false;
  bool _queueFailed = false;
  bool _entriesFailed = false;
  int _generation = 0;
  int _entriesGeneration = 0;
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

  bool get canCallNext =>
      _status == LoadStatus.ready &&
      _queue != null &&
      !_isBusy &&
      QueueRules.checkCallNext(_entries).isOk;
  bool get canFinishCalled =>
      _status == LoadStatus.ready &&
      _queue != null &&
      !_isBusy &&
      QueueRules.checkFinishCalled(_entries).isOk;

  // Called by the app when the signed-in user changes. A new user never sees
  // the queue that belongs to the previous one.
  void bindUser(AppUser? user) {
    if (user?.id == _user?.id) return;
    _user = user;
    _cancelAll();
    _queue = null;
    _entries = const [];
    _resetLoading();
    _actionError = null;
    _isBusy = false;
    if (user != null && user.role == UserRole.provider) {
      final generation = _generation;
      scheduleMicrotask(() {
        if (_generation == generation) _subscribe();
      });
    }
    scheduleMicrotask(notifyListeners);
  }

  void retry() {
    if (_user == null) return;
    _cancelAll();
    _entries = const [];
    _resetLoading();
    notifyListeners();
    _subscribe();
  }

  void _resetLoading() {
    _queueLoaded = false;
    _entriesLoaded = false;
    _queueFailed = false;
    _entriesFailed = false;
    _status = LoadStatus.loading;
    _loadError = null;
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
    final generation = _generation;
    _queueSubscription = _repository
        .watchQueueOfProvider(user.id)
        .listen(
          (queue) {
            if (generation == _generation) _onQueue(queue);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (generation != _generation) return;
            _queueFailed = true;
            _updateStatus();
            notifyListeners();
          },
        );
  }

  void _onQueue(ServiceQueue? queue) {
    _queue = queue;
    _queueLoaded = true;
    _queueFailed = false;
    if (queue == null || _watchedQueueId != queue.id) {
      _entriesGeneration++;
      _entriesSubscription?.cancel();
      _entriesSubscription = null;
      _watchedQueueId = queue?.id;
      _entries = const [];
      _entriesLoaded = false;
      _entriesFailed = false;
      if (queue != null) {
        final generation = _generation;
        final entriesGeneration = _entriesGeneration;
        bool isCurrent() =>
            generation == _generation &&
            entriesGeneration == _entriesGeneration;
        _entriesSubscription = _repository
            .watchEntries(queue.id)
            .listen(
              (entries) {
                if (!isCurrent()) return;
                _entries = entries;
                _entriesLoaded = true;
                _entriesFailed = false;
                _updateStatus();
                notifyListeners();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!isCurrent()) return;
                _entriesFailed = true;
                _updateStatus();
                notifyListeners();
              },
            );
      }
    }
    _updateStatus();
    notifyListeners();
  }

  // A queue with no entries is ready only after an actual empty snapshot.
  // Each stream clears its own error without hiding a failure in the other.
  void _updateStatus() {
    if (_queueFailed || _entriesFailed) {
      _status = LoadStatus.error;
      _loadError =
          'Could not load your queue. Check your connection and retry.';
    } else {
      _status = _queueLoaded && (_queue == null || _entriesLoaded)
          ? LoadStatus.ready
          : LoadStatus.loading;
      _loadError = null;
    }
  }

  void _cancelAll() {
    _generation++;
    _entriesGeneration++;
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
