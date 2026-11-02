import 'dart:async';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';

// Queue data source. For now it keeps dummy data in memory, so the app runs
// and can be tested before the data layer is connected: nothing is saved after
// the app closes, and it seeds one sample queue (Campus Barber) with four
// customers. `latency` makes the Joining and Leaving states visible.
//
// The data layer replaces the body of these methods with Firebase reads and
// writes. Method names, parameters and results stay the same, so no Provider
// or screen changes.
class QueueRepository {
  QueueRepository({
    this.latency = Duration.zero,
    bool seedSampleData = true,
  }) {
    if (seedSampleData) _seed();
  }

  // A delay lets the screens show their Joining and Leaving states.
  final Duration latency;

  final List<ServiceQueue> _queues = [];
  final List<QueueEntry> _entries = [];
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  int _nextId = 100;

  void _seed() {
    _queues.add(
      const ServiceQueue(
        id: 'campus-barber',
        providerId: 'provider-1',
        name: 'Campus Barber',
        description: 'Barber service',
        averageServiceMinutes: 5,
        isOpen: true,
      ),
    );
    final people = [
      ('e9', 'c09', 'Ahmed Ali', 9, 0, MembershipStatus.called),
      ('e10', 'c10', 'Sara Hassan', 10, 2, MembershipStatus.waiting),
      ('e11', 'c11', 'Omar Khalid', 11, 4, MembershipStatus.waiting),
      ('e12', 'customer-1', 'Noor Abdullah', 12, 6, MembershipStatus.waiting),
    ];
    for (final person in people) {
      _entries.add(
        QueueEntry(
          id: person.$1,
          customerId: person.$2,
          customerName: person.$3,
          queueId: 'campus-barber',
          ticketNumber: person.$4,
          joinedAt: DateTime(2026, 10, 13, 10, person.$5),
          status: person.$6,
        ),
      );
    }
  }

  Future<void> _delay() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  Stream<T> _watch<T>(T Function() read) => Stream<T>.multi((controller) {
    controller.add(read());
    final subscription = _changes.stream.listen((_) => controller.add(read()));
    controller.onCancel = subscription.cancel;
  });

  ServiceQueue? _queueById(String id) {
    for (final queue in _queues) {
      if (queue.id == id) return queue;
    }
    return null;
  }

  List<QueueEntry> _entriesOf(String queueId) =>
      _entries.where((entry) => entry.queueId == queueId).toList();

  void _replace(QueueEntry updated) {
    final index = _entries.indexWhere((entry) => entry.id == updated.id);
    if (index >= 0) _entries[index] = updated;
    _changes.add(null);
  }

  Stream<List<QueueSummary>> watchQueueSummaries() => _watch(
    () => [
      for (final queue in _queues)
        QueueSummary(
          queue: queue,
          waitingCount: QueueRules.waitingEntries(_entriesOf(queue.id)).length,
          calledCount: QueueRules.calledEntry(_entriesOf(queue.id)) == null
              ? 0
              : 1,
        ),
    ],
  );

  Stream<ServiceQueue?> watchQueue(String queueId) =>
      _watch(() => _queueById(queueId));

  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) => _watch(() {
    for (final queue in _queues) {
      if (queue.providerId == providerId) return queue;
    }
    return null;
  });

  Stream<List<QueueEntry>> watchEntries(String queueId) =>
      _watch(() => _entriesOf(queueId));

  Stream<QueueEntry?> watchLatestEntryOfCustomer(String customerId) =>
      _watch(() {
        final own = _entries
            .where((entry) => entry.customerId == customerId)
            .toList();
        if (own.isEmpty) return null;
        own.sort((a, b) {
          final byTime = b.joinedAt.compareTo(a.joinedAt);
          return byTime != 0
              ? byTime
              : b.ticketNumber.compareTo(a.ticketNumber);
        });
        return own.first;
      });

  Future<OperationResult> createQueue({
    required AppUser provider,
    required String name,
    required String description,
    required int averageServiceMinutes,
  }) async {
    await _delay();
    final check = QueueRules.checkCreateQueue(
      user: provider,
      hasQueue: _queues.any((queue) => queue.providerId == provider.id),
      name: name,
      averageServiceMinutes: averageServiceMinutes,
    );
    if (!check.isOk) return check;
    _queues.add(
      ServiceQueue(
        id: 'q${_nextId++}',
        providerId: provider.id,
        name: name.trim(),
        description: description.trim(),
        averageServiceMinutes: averageServiceMinutes,
        isOpen: true,
      ),
    );
    _changes.add(null);
    return OperationResult.ok;
  }

  Future<OperationResult> join({
    required AppUser customer,
    required String queueId,
  }) async {
    await _delay();
    final check = QueueRules.checkJoin(
      user: customer,
      queue: _queueById(queueId),
      hasActiveMembership: _entries.any(
        (entry) => entry.customerId == customer.id && entry.isActive,
      ),
    );
    if (!check.isOk) return check;
    _entries.add(
      QueueEntry(
        id: 'e${_nextId++}',
        customerId: customer.id,
        customerName: customer.name,
        queueId: queueId,
        ticketNumber: QueueRules.nextTicketNumber(_entriesOf(queueId)),
        joinedAt: DateTime.now(),
        status: MembershipStatus.waiting,
      ),
    );
    _changes.add(null);
    return OperationResult.ok;
  }

  Future<OperationResult> leave({
    required AppUser customer,
    required String entryId,
  }) async {
    await _delay();
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index < 0) {
      return OperationResult.failure(OperationError.notWaiting);
    }
    final entry = _entries[index];
    if (entry.customerId != customer.id) {
      return OperationResult.failure(OperationError.notOwner);
    }
    final check = QueueRules.checkLeave(entry);
    if (!check.isOk) return check;
    _replace(entry.copyWith(status: MembershipStatus.left));
    return OperationResult.ok;
  }

  OperationResult _checkOwner(AppUser provider, String queueId) {
    final queue = _queueById(queueId);
    if (queue == null) {
      return OperationResult.failure(OperationError.queueNotFound);
    }
    if (provider.role != UserRole.provider || queue.providerId != provider.id) {
      return OperationResult.failure(OperationError.notOwner);
    }
    return OperationResult.ok;
  }

  Future<OperationResult> callNext({
    required AppUser provider,
    required String queueId,
  }) async {
    await _delay();
    final owner = _checkOwner(provider, queueId);
    if (!owner.isOk) return owner;
    final entries = _entriesOf(queueId);
    final check = QueueRules.checkCallNext(entries);
    if (!check.isOk) return check;
    final next = QueueRules.waitingEntries(entries).first;
    _replace(next.copyWith(status: MembershipStatus.called));
    return OperationResult.ok;
  }

  Future<OperationResult> finishCalled({
    required AppUser provider,
    required String queueId,
    required MembershipStatus outcome,
  }) async {
    await _delay();
    if (outcome != MembershipStatus.served &&
        outcome != MembershipStatus.skipped) {
      return OperationResult.failure(OperationError.invalidInput);
    }
    final owner = _checkOwner(provider, queueId);
    if (!owner.isOk) return owner;
    final entries = _entriesOf(queueId);
    final check = QueueRules.checkFinishCalled(entries);
    if (!check.isOk) return check;
    _replace(QueueRules.calledEntry(entries)!.copyWith(status: outcome));
    return OperationResult.ok;
  }
}

class _Account {
  const _Account(this.user, this.password);
  final AppUser user;
  final String password;
}

// Account data source. For now it keeps dummy accounts in memory (seeded test
// accounts: customer@example.com and provider@example.com, both with the
// password demopass); the passwords are kept in memory for testing only.
//
// The data layer replaces the body of these methods with Firebase
// Authentication. authStateChanges must emit the current user or null, restore
// the session on start, and the user's name and role are stored on
// registration. Results are an AuthOutcome: the user on success, or an
// OperationError on failure.
class AuthRepository {
  AuthRepository({
    this.latency = Duration.zero,
    bool seedDemoAccounts = true,
  }) {
    if (seedDemoAccounts) {
      _add(
        const AppUser(
          id: 'customer-1',
          name: 'Noor Abdullah',
          email: 'customer@example.com',
          role: UserRole.customer,
        ),
        'demopass',
      );
      _add(
        const AppUser(
          id: 'provider-1',
          name: 'Campus Barber Owner',
          email: 'provider@example.com',
          role: UserRole.provider,
        ),
        'demopass',
      );
    }
  }

  final Duration latency;

  final Map<String, _Account> _accounts = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  AppUser? _current;
  int _nextUser = 1;

  void _add(AppUser user, String password) =>
      _accounts[user.email.toLowerCase()] = _Account(user, password);

  Future<void> _delay() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.multi((controller) {
    controller.add(_current);
    final subscription = _changes.stream.listen(
      (_) => controller.add(_current),
    );
    controller.onCancel = subscription.cancel;
  });

  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    await _delay();
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      return AuthOutcome(
        OperationResult.failure(OperationError.invalidCredentials),
      );
    }
    _current = account.user;
    _changes.add(null);
    return AuthOutcome(OperationResult.ok, account.user);
  }

  Future<AuthOutcome> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _delay();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      return AuthOutcome(OperationResult.failure(OperationError.emailInUse));
    }
    final user = AppUser(
      id: 'user-${_nextUser++}',
      name: name.trim(),
      email: email.trim(),
      role: role,
    );
    _add(user, password);
    _current = user;
    _changes.add(null);
    return AuthOutcome(OperationResult.ok, user);
  }

  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }
}