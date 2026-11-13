import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/provider_queue_provider.dart';
import 'package:swe463_group7_project/providers/provider_support.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';

const _owner = AppUser(
  id: 'loading-owner',
  name: 'Loading test provider',
  email: 'loading-owner@example.com',
  role: UserRole.provider,
);

const _queue = ServiceQueue(
  id: 'loading-queue',
  providerId: 'loading-owner',
  name: 'Loading test queue',
  description: 'Controlled stream tests',
  averageServiceMinutes: 5,
  isOpen: true,
);

class _StreamRepository extends QueueRepository {
  _StreamRepository() : super(seedSampleData: false);

  final queues = StreamController<ServiceQueue?>.broadcast();
  final entries = StreamController<List<QueueEntry>>.broadcast();
  final otherEntries = StreamController<List<QueueEntry>>.broadcast();
  int entrySubscriptions = 0;

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) =>
      queues.stream;

  @override
  Stream<List<QueueEntry>> watchEntries(String queueId) {
    entrySubscriptions++;
    return queueId == _queue.id ? entries.stream : otherEntries.stream;
  }

  Future<void> close() async {
    await queues.close();
    await entries.close();
    await otherEntries.close();
  }
}

QueueEntry _waiting() => QueueEntry(
  id: 'loading-entry',
  customerId: 'loading-customer',
  customerName: 'Waiting customer',
  queueId: _queue.id,
  ticketNumber: 1,
  joinedAt: DateTime(2026, 11, 13),
  status: MembershipStatus.waiting,
);

void main() {
  late _StreamRepository repository;
  late ProviderQueueProvider state;

  setUp(() async {
    repository = _StreamRepository();
    state = ProviderQueueProvider(repository)..bindUser(_owner);
    await pumpEventQueue();
  });

  tearDown(() async {
    state.dispose();
    await repository.close();
  });

  Future<void> emitQueue() async {
    repository.queues.add(_queue);
    await pumpEventQueue();
  }

  Future<void> makeReady() async {
    await emitQueue();
    repository.entries.add([_waiting()]);
    await pumpEventQueue();
    expect(state.status, LoadStatus.ready);
  }

  test(
    'waits for the first entries snapshot, including a real empty list',
    () async {
      expect(state.status, LoadStatus.loading);
      await emitQueue();
      expect(state.queue?.id, _queue.id);
      expect(state.status, LoadStatus.loading);
      expect(state.canCallNext, isFalse);
      expect(state.canFinishCalled, isFalse);

      // Repeated metadata cannot turn pending entries into an empty result.
      await emitQueue();
      expect(state.status, LoadStatus.loading);
      expect(repository.entrySubscriptions, 1);
      repository.entries.add([]);
      await pumpEventQueue();
      expect(state.status, LoadStatus.ready);
      expect(state.waitingEntries, isEmpty);
    },
  );

  test(
    'a missing provider queue is ready without an entries snapshot',
    () async {
      repository.queues.add(null);
      await pumpEventQueue();
      expect(state.status, LoadStatus.ready);
      expect(state.queue, isNull);
      expect(repository.entrySubscriptions, 0);
    },
  );

  test('entries recover from an initial stream error without Retry', () async {
    await emitQueue();
    repository.entries.addError(StateError('entries unavailable'));
    await pumpEventQueue();
    expect(state.status, LoadStatus.error);
    expect(state.loadError, isNotNull);

    repository.entries.add([_waiting()]);
    await pumpEventQueue();
    expect(state.status, LoadStatus.ready);
    expect(state.loadError, isNull);
    expect(state.waitingEntries.single.id, 'loading-entry');
    expect(state.canCallNext, isTrue);
  });

  test('queue metadata does not hide an entries error', () async {
    await makeReady();
    repository.entries.addError(StateError('entries unavailable'));
    await pumpEventQueue();
    await emitQueue();
    expect(state.status, LoadStatus.error);
    expect(state.loadError, isNotNull);
    expect(state.canCallNext, isFalse);
    repository.entries.add([]);
    await pumpEventQueue();
    expect(state.status, LoadStatus.ready);
    expect(state.loadError, isNull);
  });

  test('entries recovery does not hide a queue stream error', () async {
    await makeReady();
    repository.queues.addError(StateError('queue unavailable'));
    repository.entries.addError(StateError('entries unavailable'));
    await pumpEventQueue();
    repository.entries.add([_waiting()]);
    await pumpEventQueue();
    expect(state.status, LoadStatus.error);
    expect(state.canCallNext, isFalse);

    await emitQueue();
    expect(state.status, LoadStatus.ready);
    expect(state.loadError, isNull);
    expect(state.canCallNext, isTrue);
  });

  test('queue recovery still waits if no entries have arrived', () async {
    await emitQueue();
    repository.queues.addError(StateError('queue unavailable'));
    await pumpEventQueue();
    expect(state.status, LoadStatus.error);
    await emitQueue();
    expect(state.status, LoadStatus.loading);
    expect(state.loadError, isNull);
    repository.entries.add([]);
    await pumpEventQueue();
    expect(state.status, LoadStatus.ready);
  });

  test(
    'Retry requires fresh entries instead of reusing the old list',
    () async {
      await makeReady();
      state.retry();
      await pumpEventQueue();
      await emitQueue();
      expect(state.status, LoadStatus.loading);
      expect(state.waitingEntries, isEmpty);
      expect(state.canCallNext, isFalse);
      repository.entries.add([_waiting()]);
      await pumpEventQueue();
      expect(state.status, LoadStatus.ready);
      expect(state.canCallNext, isTrue);
      expect(repository.entrySubscriptions, 2);
    },
  );

  test(
    'switching queues waits for its own entries and ignores the old stream',
    () async {
      await makeReady();
      repository.queues.add(
        const ServiceQueue(
          id: 'replacement-queue',
          providerId: 'loading-owner',
          name: 'Replacement queue',
          description: 'New subscription',
          averageServiceMinutes: 5,
          isOpen: true,
        ),
      );
      await pumpEventQueue();
      expect(state.status, LoadStatus.loading);
      expect(state.waitingEntries, isEmpty);
      repository.entries.add([_waiting()]);
      repository.entries.addError(StateError('old stream'));
      await pumpEventQueue();
      expect(state.status, LoadStatus.loading);
      repository.otherEntries.add([]);
      await pumpEventQueue();
      expect(state.status, LoadStatus.ready);
      expect(state.loadError, isNull);
      expect(state.waitingEntries, isEmpty);
    },
  );

  test('logout drops previous stream data and errors', () async {
    await makeReady();
    state.bindUser(null);
    repository.queues.add(_queue);
    repository.entries.add([_waiting()]);
    repository.entries.addError(StateError('previous account'));
    await pumpEventQueue();
    expect(state.queue, isNull);
    expect(state.waitingEntries, isEmpty);
    expect(state.status, LoadStatus.loading);
    expect(state.loadError, isNull);
    expect(state.canCallNext, isFalse);
  });
}
