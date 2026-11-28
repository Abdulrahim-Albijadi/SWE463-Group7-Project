import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import 'repositories.dart';

// Firestore implementation of the same API used by the existing Providers.
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
    final snapshot = await _entries
        .where('queueId', isEqualTo: queueId)
        .get(const GetOptions(source: Source.server));
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
            calledCount:
                QueueRules.calledEntry(
                      entries!.where((entry) => entry.queueId == queue.id),
                    ) ==
                    null
                ? 0
                : 1,
          ),
      ]);
    }

    queuesSubscription = _queues.snapshots().listen((snapshot) {
      queues = snapshot.docs.map(_queueFrom).toList();
      publish();
    }, onError: controller.addError);
    entriesSubscription = _entries.snapshots().listen((snapshot) {
      entries = snapshot.docs.map(_entryFrom).toList();
      publish();
    }, onError: controller.addError);
    controller.onCancel = () async {
      await queuesSubscription.cancel();
      await entriesSubscription.cancel();
    };
    return controller.stream;
  }

  @override
  Stream<ServiceQueue?> watchQueue(String queueId) => _queues
      .doc(queueId)
      .snapshots()
      .map((snapshot) => snapshot.exists ? _queueFrom(snapshot) : null);

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) => _queues
      .doc(providerId)
      .snapshots()
      .map((snapshot) => snapshot.exists ? _queueFrom(snapshot) : null);

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
      return await _db.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        final check = QueueRules.checkCreateQueue(
          user: provider,
          hasQueue: existing.exists,
          name: name,
          averageServiceMinutes: averageServiceMinutes,
        );
        if (!check.isOk) return check;
        transaction.set(ref, {
          'providerId': provider.id,
          'name': name.trim(),
          'description': description.trim(),
          'averageServiceMinutes': averageServiceMinutes,
          'isOpen': true,
        });
        transaction.set(_db.collection('queueTicketCounters').doc(ref.id), {
          'lastTicket': 0,
        });
        return OperationResult.ok;
      });
    } catch (error) {
      return OperationResult.failure(OperationError.failed);
    }
  }

  @override
  Future<OperationResult> join({
    required AppUser customer,
    required String queueId,
  }) async {
    try {
      final queueRef = _queues.doc(queueId);
      final membershipRef = _db
          .collection('customerMemberships')
          .doc(customer.id);
      final counterRef = _db.collection('queueTicketCounters').doc(queueId);
      final entryRef = _entries.doc();

      // Legacy lookups use queries, which Firestore transactions cannot read.
      // Counters and membership pointers are permanent once created, so the
      // transaction only uses these results if the corresponding doc is absent.
      const server = GetOptions(source: Source.server);
      final [membershipBeforeJoin, counterBeforeJoin] = await Future.wait([
        membershipRef.get(server),
        counterRef.get(server),
      ]);
      final legacyEntries = membershipBeforeJoin.exists
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : (await _entries
                    .where('customerId', isEqualTo: customer.id)
                    .get(server))
                .docs;
      final firstTicket = counterBeforeJoin.exists
          ? null
          : QueueRules.nextTicketNumber(
              (await _entries.where('queueId', isEqualTo: queueId).get(server))
                  .docs
                  .map(_entryFrom),
            );

      String? attemptedMembership;
      int? attemptedLastTicket;
      var wroteJoin = false;

      Future<OperationResult> joinTransaction(Transaction transaction) async {
        wroteJoin = false;
        final queueDoc = await transaction.get(queueRef);
        final queue = queueDoc.exists ? _queueFrom(queueDoc) : null;
        final queueCheck = QueueRules.checkJoin(
          user: customer,
          queue: queue,
          hasActiveMembership: false,
        );
        if (!queueCheck.isOk) return queueCheck;

        final membership = await transaction.get(membershipRef);
        final previousEntryId = membership.data()?['entryId'] as String?;
        var hasActiveMembership = false;
        final previousEntries = previousEntryId == null
            ? legacyEntries
                  .where((doc) => _entryFrom(doc).isActive)
                  .map((doc) => doc.reference)
            : [_entries.doc(previousEntryId)];
        for (final ref in previousEntries) {
          final previous = await transaction.get(ref);
          if (previous.exists && _entryFrom(previous).isActive) {
            hasActiveMembership = true;
            break;
          }
        }
        final check = QueueRules.checkJoin(
          user: customer,
          queue: queue,
          hasActiveMembership: hasActiveMembership,
        );
        if (!check.isOk) return check;

        final counter = await transaction.get(counterRef);
        final lastTicket = counter.data()?['lastTicket'] as int?;
        final ticket = lastTicket == null ? firstTicket! : lastTicket + 1;

        attemptedMembership = previousEntryId;
        attemptedLastTicket = lastTicket;
        wroteJoin = true;
        transaction.set(counterRef, {
          'lastTicket': ticket,
          'entryId': entryRef.id,
        });
        transaction.set(membershipRef, {'entryId': entryRef.id});
        transaction.set(entryRef, {
          'customerId': customer.id,
          'customerName': customer.name,
          'queueId': queueId,
          'ticketNumber': ticket,
          'joinedAt': Timestamp.fromDate(DateTime.now()),
          'status': MembershipStatus.waiting.name,
        });
        return OperationResult.ok;
      }

      for (var attempt = 1; ; attempt++) {
        try {
          return await _db.runTransaction(joinTransaction);
        } on FirebaseException catch (error) {
          if (error.code != 'permission-denied' || !wroteJoin || attempt == 3) {
            rethrow;
          }
          // Rules can reject a competing write before Firestore checks the
          // transaction's read versions. Retry only if a shared document moved.
          final [membership, counter] = await Future.wait([
            membershipRef.get(server),
            counterRef.get(server),
          ]);
          if (membership.data()?['entryId'] == attemptedMembership &&
              counter.data()?['lastTicket'] == attemptedLastTicket) {
            rethrow;
          }
        }
      }
    } catch (error) {
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
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          return OperationResult.failure(OperationError.notWaiting);
        }
        final entry = _entryFrom(snapshot);
        if (entry.customerId != customer.id) {
          return OperationResult.failure(OperationError.notOwner);
        }
        final check = QueueRules.checkLeave(entry);
        if (!check.isOk) return check;
        transaction.update(ref, {'status': MembershipStatus.left.name});
        return OperationResult.ok;
      });
    } catch (error) {
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
      final state = _db.collection('queueServiceState').doc(queueId);
      return await _db.runTransaction((transaction) async {
        final currentState = await transaction.get(state);
        final currentEntryId = currentState.data()?['entryId'] as String?;
        final entriesToCheck = {
          for (final entry in entries)
            if (entry.isActive) entry.id,
          ?currentEntryId,
        };
        final active = <QueueEntry>[];
        for (final entryId in entriesToCheck) {
          final snapshot = await transaction.get(_entries.doc(entryId));
          if (snapshot.exists) active.add(_entryFrom(snapshot));
        }

        final check = QueueRules.checkCallNext(active);
        if (!check.isOk) return check;
        final next = QueueRules.waitingEntries(active).first;
        transaction.set(state, {'entryId': next.id});
        transaction.update(_entries.doc(next.id), {
          'status': MembershipStatus.called.name,
        });
        return OperationResult.ok;
      });
    } catch (error) {
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
      final called = QueueRules.calledEntry(entries);
      if (called == null) {
        return OperationResult.failure(OperationError.nothingCalled);
      }

      final ref = _entries.doc(called.id);
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (snapshot.data()?['status'] != MembershipStatus.called.name) {
          return OperationResult.failure(OperationError.nothingCalled);
        }
        transaction.update(ref, {'status': outcome.name});
        return OperationResult.ok;
      });
    } catch (error) {
      return OperationResult.failure(OperationError.failed);
    }
  }
}
