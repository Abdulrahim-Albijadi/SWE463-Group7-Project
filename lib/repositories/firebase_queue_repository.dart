import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import 'repositories.dart';

// Firestore implementation of the same API used by the existing Providers.
// Phase 3 prototype: ticket numbers are assigned client-side and are not
// guaranteed unique if multiple customers join at exactly the same time.
class FirebaseQueueRepository extends QueueRepository {
  FirebaseQueueRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        super(seedSampleData: false);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _queues =>
      _db.collection('queues');
  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('entries');

  ServiceQueue _queueFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ServiceQueue(
      id: doc.id,
      providerId: data['providerId'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      averageServiceMinutes: (data['averageServiceMinutes'] as num).toInt(),
      isOpen: data['isOpen'] == true,
    );
  }

  QueueEntry _entryFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final statusName = data['status'] as String? ?? 'waiting';
    return QueueEntry(
      id: doc.id,
      customerId: data['customerId'] as String,
      customerName: data['customerName'] as String,
      queueId: data['queueId'] as String,
      ticketNumber: (data['ticketNumber'] as num).toInt(),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      status: MembershipStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => MembershipStatus.waiting,
      ),
    );
  }

  Future<List<QueueEntry>> _entriesOf(String queueId) async {
    final snapshot =
        await _entries.where('queueId', isEqualTo: queueId).get();
    return snapshot.docs.map(_entryFrom).toList();
  }

  // Recompute summaries whenever either the queues or the entries change.
  @override
  Stream<List<QueueSummary>> watchQueueSummaries() {
    late StreamSubscription queuesSubscription;
    late StreamSubscription entriesSubscription;
    final controller = StreamController<List<QueueSummary>>();
    List<ServiceQueue>? queues;
    List<QueueEntry>? entries;

    void publish() {
      if (queues == null || entries == null || controller.isClosed) return;
      controller.add([
        for (final queue in queues!)
          QueueSummary(
            queue: queue,
            waitingCount: QueueRules.waitingEntries(
              entries!.where((entry) => entry.queueId == queue.id),
            ).length,
            calledCount: QueueRules.calledEntry(
              entries!.where((entry) => entry.queueId == queue.id),
            ) == null
                ? 0
                : 1,
          ),
      ]);
    }

    queuesSubscription = _queues.snapshots().listen(
      (snapshot) {
        queues = snapshot.docs.map(_queueFrom).toList();
        publish();
      },
      onError: controller.addError,
    );
    entriesSubscription = _entries.snapshots().listen(
      (snapshot) {
        entries = snapshot.docs.map(_entryFrom).toList();
        publish();
      },
      onError: controller.addError,
    );
    controller.onCancel = () async {
      await queuesSubscription.cancel();
      await entriesSubscription.cancel();
    };
    return controller.stream;
  }

  @override
  Stream<ServiceQueue?> watchQueue(String queueId) =>
      _queues.doc(queueId).snapshots().map(
        (snapshot) => snapshot.exists ? _queueFrom(snapshot) : null,
      );

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) =>
      _queues.doc(providerId).snapshots().map(
        (snapshot) => snapshot.exists ? _queueFrom(snapshot) : null,
      );

  @override
  Stream<List<QueueEntry>> watchEntries(String queueId) => _entries
      .where('queueId', isEqualTo: queueId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_entryFrom).toList());

  @override
  Stream<QueueEntry?> watchLatestEntryOfCustomer(String customerId) => _entries
      .where('customerId', isEqualTo: customerId)
      .snapshots()
      .map((snapshot) {
        final own = snapshot.docs.map(_entryFrom).toList()
          ..sort((a, b) {
            final byTime = b.joinedAt.compareTo(a.joinedAt);
            return byTime != 0
                ? byTime
                : b.ticketNumber.compareTo(a.ticketNumber);
          });
        return own.isEmpty ? null : own.first;
      });

  @override
  Future<OperationResult> createQueue({
    required AppUser provider,
    required String name,
    required String description,
    required int averageServiceMinutes,
  }) async {
    try {
      // One fixed document ID per provider prevents duplicate queues.
      final ref = _queues.doc(provider.id);
      final existing = await ref.get();
      final check = QueueRules.checkCreateQueue(
        user: provider,
        hasQueue: existing.exists,
        name: name,
        averageServiceMinutes: averageServiceMinutes,
      );
      if (!check.isOk) return check;
      await ref.set({
        'providerId': provider.id,
        'name': name.trim(),
        'description': description.trim(),
        'averageServiceMinutes': averageServiceMinutes,
        'isOpen': true,
      });
      return OperationResult.ok;
    } catch (error) {
      debugPrint('Firestore createQueue failed: $error');
      return OperationResult.failure(OperationError.failed);
    }
  }

  @override
  Future<OperationResult> join({
    required AppUser customer,
    required String queueId,
  }) async {
    try {
      final queueDoc = await _queues.doc(queueId).get();
      final ownDocs = await _entries
          .where('customerId', isEqualTo: customer.id)
          .get();
      final ownEntries = ownDocs.docs.map(_entryFrom);
      final check = QueueRules.checkJoin(
        user: customer,
        queue: queueDoc.exists ? _queueFrom(queueDoc) : null,
        hasActiveMembership: ownEntries.any((entry) => entry.isActive),
      );
      if (!check.isOk) return check;
      final queueEntries = await _entriesOf(queueId);
      await _entries.add({
        'customerId': customer.id,
        'customerName': customer.name,
        'queueId': queueId,
        'ticketNumber': QueueRules.nextTicketNumber(queueEntries),
        'joinedAt': Timestamp.fromDate(DateTime.now()),
        'status': MembershipStatus.waiting.name,
      });
      return OperationResult.ok;
    } catch (error) {
      debugPrint('Firestore join failed: $error');
      return OperationResult.failure(OperationError.failed);
    }
  }

  @override
  Future<OperationResult> leave({
    required AppUser customer,
    required String entryId,
  }) async {
    try {
      final ref = _entries.doc(entryId);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return OperationResult.failure(OperationError.notWaiting);
      }
      final entry = _entryFrom(snapshot);
      if (entry.customerId != customer.id) {
        return OperationResult.failure(OperationError.notOwner);
      }
      final check = QueueRules.checkLeave(entry);
      if (!check.isOk) return check;
      await ref.update({'status': MembershipStatus.left.name});
      return OperationResult.ok;
    } catch (error) {
      debugPrint('Firestore leave failed: $error');
      return OperationResult.failure(OperationError.failed);
    }
  }

  Future<OperationResult> _checkOwner(AppUser provider, String queueId) async {
    final doc = await _queues.doc(queueId).get();
    if (!doc.exists) {
      return OperationResult.failure(OperationError.queueNotFound);
    }
    if (provider.role != UserRole.provider ||
        _queueFrom(doc).providerId != provider.id) {
      return OperationResult.failure(OperationError.notOwner);
    }
    return OperationResult.ok;
  }

  @override
  Future<OperationResult> callNext({
    required AppUser provider,
    required String queueId,
  }) async {
    try {
      final owner = await _checkOwner(provider, queueId);
      if (!owner.isOk) return owner;
      final entries = await _entriesOf(queueId);
      final check = QueueRules.checkCallNext(entries);
      if (!check.isOk) return check;
      final next = QueueRules.waitingEntries(entries).first;
      await _entries.doc(next.id).update({'status': MembershipStatus.called.name});
      return OperationResult.ok;
    } catch (error) {
      debugPrint('Firestore callNext failed: $error');
      return OperationResult.failure(OperationError.failed);
    }
  }

  @override
  Future<OperationResult> finishCalled({
    required AppUser provider,
    required String queueId,
    required MembershipStatus outcome,
  }) async {
    if (outcome != MembershipStatus.served &&
        outcome != MembershipStatus.skipped) {
      return OperationResult.failure(OperationError.invalidInput);
    }
    try {
      final owner = await _checkOwner(provider, queueId);
      if (!owner.isOk) return owner;
      final entries = await _entriesOf(queueId);
      final check = QueueRules.checkFinishCalled(entries);
      if (!check.isOk) return check;
      final called = QueueRules.calledEntry(entries)!;
      await _entries.doc(called.id).update({'status': outcome.name});
      return OperationResult.ok;
    } catch (error) {
      debugPrint('Firestore finishCalled failed: $error');
      return OperationResult.failure(OperationError.failed);
    }
  }
}
