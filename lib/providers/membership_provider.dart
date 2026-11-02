import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import '../repositories/repositories.dart';
import 'provider_support.dart';

// The signed-in customer's ticket: position, wait, status and in-app alerts.
class MembershipProvider extends ChangeNotifier with SafeNotifier {
  MembershipProvider(this._repository);

  final QueueRepository _repository;
  final StreamController<QueueNotification> _alerts =
      StreamController<QueueNotification>.broadcast();
  final Set<String> _announced = {};

  StreamSubscription<QueueEntry?>? _entrySubscription;
  StreamSubscription<ServiceQueue?>? _queueSubscription;
  StreamSubscription<List<QueueEntry>>? _entriesSubscription;
  AppUser? _user;
  QueueEntry? _entry;
  ServiceQueue? _queue;
  String? _watchedQueueId;
  List<QueueEntry> _queueEntries = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _loadError;
  bool _isJoining = false;
  bool _isLeaving = false;
  String? _joinError;
  String? _leaveError;

  // One-time messages when the customer is near their turn or called.
  Stream<QueueNotification> get alerts => _alerts.stream;

  LoadStatus get status => _status;
  String? get loadError => _loadError;
  bool get isJoining => _isJoining;
  bool get isLeaving => _isLeaving;
  String? get joinError => _joinError;
  String? get leaveError => _leaveError;

  // The active entry, or the most recent finished one.
  QueueEntry? get currentEntry => _entry;
  ServiceQueue? get queue => _queue;
  bool get hasActiveMembership => _entry?.isActive ?? false;
  bool get isWaiting => _entry?.status == MembershipStatus.waiting;
  bool get isCalled => _entry?.status == MembershipStatus.called;

  int? get position {
    final entry = _entry;
    if (entry == null || !entry.isActive) return null;
    return QueueRules.positionOf(_queueEntries, entry.id);
  }

  int? get customersAhead {
    final position = this.position;
    return position == null ? null : position - 1;
  }

  int? get estimatedWaitMinutes {
    final ahead = customersAhead;
    final queue = _queue;
    if (ahead == null || queue == null) return null;
    return QueueRules.estimatedWaitMinutes(
      customersAhead: ahead,
      averageServiceMinutes: queue.averageServiceMinutes,
    );
  }

  bool get isNearTurn {
    final entry = _entry;
    final ahead = customersAhead;
    if (entry == null || ahead == null) return false;
    return QueueRules.isNearTurn(entry: entry, customersAhead: ahead);
  }

  // Called by the app when the signed-in user changes. A new user never sees
  // the ticket or alerts that belong to the previous one.
  void bindUser(AppUser? user) {
    if (user?.id == _user?.id) return;
    _user = user;
    _cancelAll();
    _entry = null;
    _queue = null;
    _queueEntries = const [];
    _announced.clear();
    _status = LoadStatus.loading;
    _loadError = null;
    _joinError = null;
    _leaveError = null;
    _isJoining = false;
    _isLeaving = false;
    if (user != null && user.role == UserRole.customer) {
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

  void clearErrors() {
    if (_joinError == null && _leaveError == null) return;
    _joinError = null;
    _leaveError = null;
    notifyListeners();
  }

  Future<OperationResult> join(String queueId) async {
    final user = _user;
    if (user == null) {
      return OperationResult.failure(OperationError.notSignedIn);
    }
    if (_isJoining || _isLeaving) {
      return OperationResult.failure(OperationError.busy);
    }
    _isJoining = true;
    _joinError = null;
    notifyListeners();
    OperationResult result;
    try {
      result = await _repository.join(customer: user, queueId: queueId);
    } catch (_) {
      result = OperationResult.failure(OperationError.failed);
    }
    _isJoining = false;
    _joinError = result.message;
    notifyListeners();
    return result;
  }

  Future<OperationResult> leave() async {
    final user = _user;
    final entry = _entry;
    if (user == null) {
      return OperationResult.failure(OperationError.notSignedIn);
    }
    if (_isJoining || _isLeaving) {
      return OperationResult.failure(OperationError.busy);
    }
    final check = QueueRules.checkLeave(entry);
    if (!check.isOk) {
      _leaveError = check.message;
      notifyListeners();
      return check;
    }
    _isLeaving = true;
    _leaveError = null;
    notifyListeners();
    OperationResult result;
    try {
      result = await _repository.leave(customer: user, entryId: entry!.id);
    } catch (_) {
      result = OperationResult.failure(OperationError.failed);
    }
    _isLeaving = false;
    _leaveError = result.message;
    notifyListeners();
    return result;
  }

  void _subscribe() {
    final user = _user;
    if (user == null) return;
    _entrySubscription = _repository
        .watchLatestEntryOfCustomer(user.id)
        .listen(_onEntry, onError: _onError);
  }

  void _onEntry(QueueEntry? entry) {
    _entry = entry;
    _status = LoadStatus.ready;
    _loadError = null;
    if (entry == null) {
      _stopQueueWatch();
      _queue = null;
    } else {
      if (_watchedQueueId != entry.queueId) {
        _stopQueueWatch();
        _watchedQueueId = entry.queueId;
        _queueSubscription = _repository
            .watchQueue(entry.queueId)
            .listen(_onQueue, onError: _onError);
      }
      if (entry.isActive) {
        _entriesSubscription ??= _repository
            .watchEntries(entry.queueId)
            .listen(_onEntries, onError: _onError);
      } else {
        _entriesSubscription?.cancel();
        _entriesSubscription = null;
        _queueEntries = const [];
      }
    }
    _announceIfNeeded();
    notifyListeners();
  }

  void _onQueue(ServiceQueue? queue) {
    _queue = queue;
    notifyListeners();
  }

  void _onEntries(List<QueueEntry> entries) {
    _queueEntries = entries;
    _announceIfNeeded();
    notifyListeners();
  }

  void _onError(Object error, StackTrace stackTrace) {
    _status = LoadStatus.error;
    _loadError = 'Could not load your ticket. Check your connection and retry.';
    notifyListeners();
  }

  // Each alert is sent once per ticket, so repeated updates do not repeat it.
  void _announceIfNeeded() {
    final entry = _entry;
    if (entry == null) return;
    if (isCalled) {
      _announce(
        entry,
        NotificationType.called,
        'It is your turn at ${_queue?.name ?? 'the queue'}.',
      );
    } else if (isNearTurn) {
      _announce(
        entry,
        NotificationType.nearTurn,
        'Two customers are ahead of you.',
      );
    }
  }

  void _announce(QueueEntry entry, NotificationType type, String message) {
    if (!_announced.add('${entry.id}:${type.name}')) return;
    _alerts.add(
      QueueNotification(
        recipientId: entry.customerId,
        type: type,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _stopQueueWatch() {
    _queueSubscription?.cancel();
    _queueSubscription = null;
    _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _watchedQueueId = null;
    _queueEntries = const [];
  }

  void _cancelAll() {
    _entrySubscription?.cancel();
    _entrySubscription = null;
    _stopQueueWatch();
  }

  @override
  void dispose() {
    _cancelAll();
    _alerts.close();
    super.dispose();
  }
}