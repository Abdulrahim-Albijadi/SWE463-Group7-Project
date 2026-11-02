import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import '../repositories/repositories.dart';
import 'provider_support.dart';

// Available queues for customers, and the queue a customer is looking at.
class QueueProvider extends ChangeNotifier with SafeNotifier {
  QueueProvider(this._repository);
  final QueueRepository _repository;
  StreamSubscription<List<QueueSummary>>? _subscription;
  String? _userId;
  String? _selectedQueueId;
  List<QueueSummary> _summaries = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  List<QueueSummary> get summaries => _summaries;
  LoadStatus get status => _status;
  String? get error => _error;

  QueueSummary? get selected {
    for (final summary in _summaries) {
      if (summary.queue.id == _selectedQueueId) return summary;
    }
    return null;
  }

  // Customers ahead of someone who joins now: everyone waiting or called.
  int customersAheadIfJoined(QueueSummary summary) => summary.activeCount;

  int estimatedWaitIfJoined(QueueSummary summary) =>
      QueueRules.estimatedWaitMinutes(
        customersAhead: customersAheadIfJoined(summary),
        averageServiceMinutes: summary.queue.averageServiceMinutes,
      );

  // Called by the app when the signed-in user changes. A new user never sees
  // data that belongs to the previous one.
  void bindUser(AppUser? user) {
    if (user?.id == _userId) return;
    _userId = user?.id;
    _subscription?.cancel();
    _subscription = null;
    _summaries = const [];
    _selectedQueueId = null;
    _error = null;
    _status = LoadStatus.loading;
    if (user != null) {
      final id = user.id;
      scheduleMicrotask(() {
        if (_userId == id) _subscribe();
      });
    }
    scheduleMicrotask(notifyListeners);
  }

  void select(String queueId) {
    _selectedQueueId = queueId;
    notifyListeners();
  }

  void retry() {
    if (_userId == null) return;
    _subscription?.cancel();
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    _subscribe();
  }

  void _subscribe() {
    _subscription = _repository.watchQueueSummaries().listen(
      (summaries) {
        _summaries = summaries;
        _status = LoadStatus.ready;
        _error = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _status = LoadStatus.error;
        _error = 'Could not load queues. Check your connection and retry.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}