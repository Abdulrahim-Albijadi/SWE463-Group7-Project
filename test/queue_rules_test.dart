import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/models/queue_data.dart';

const customer = AppUser(
  id: 'c1',
  name: 'Customer',
  email: 'c1@example.com',
  role: UserRole.customer,
);
const provider = AppUser(
  id: 'p1',
  name: 'Provider',
  email: 'p1@example.com',
  role: UserRole.provider,
);
const openQueue = ServiceQueue(
  id: 'q1',
  providerId: 'p1',
  name: 'Barber',
  description: '',
  averageServiceMinutes: 5,
  isOpen: true,
);

QueueEntry entry(
  int ticket,
  MembershipStatus status, {
  int? minute,
  String? customerId,
}) => QueueEntry(
  id: 'e$ticket',
  customerId: customerId ?? 'c$ticket',
  customerName: 'Customer $ticket',
  queueId: 'q1',
  ticketNumber: ticket,
  joinedAt: DateTime(2026, 10, 13, 10, minute ?? ticket),
  status: status,
);

// Rule tests: joining order, fixed tickets, the called customer counting
// ahead, near turn, one active membership, leaving only while waiting, and the
// provider action checks.
void main() {
  group('order, position and estimate', () {
    test('active entries keep joining order and skip finished ones', () {
      final entries = [
        entry(3, MembershipStatus.waiting),
        entry(1, MembershipStatus.served),
        entry(2, MembershipStatus.called),
        entry(4, MembershipStatus.left),
      ];
      final active = QueueRules.activeEntries(entries);
      expect(active.map((e) => e.ticketNumber), [2, 3]);
    });

    test('equal joining times are ordered by ticket number', () {
      final entries = [
        entry(2, MembershipStatus.waiting, minute: 5),
        entry(1, MembershipStatus.waiting, minute: 5),
      ];
      expect(
        QueueRules.activeEntries(entries).map((e) => e.ticketNumber),
        [1, 2],
      );
    });

    test('the called customer counts ahead of waiting customers', () {
      final entries = [
        entry(1, MembershipStatus.called),
        entry(2, MembershipStatus.waiting),
        entry(3, MembershipStatus.waiting),
      ];
      expect(QueueRules.positionOf(entries, 'e3'), 3);
      expect(QueueRules.customersAhead(entries, 'e3'), 2);
      expect(
        QueueRules.estimatedWaitMinutes(
          customersAhead: 2,
          averageServiceMinutes: 5,
        ),
        10,
      );
    });

    test('position and wait fall as customers ahead finish', () {
      final entries = [
        entry(1, MembershipStatus.served),
        entry(2, MembershipStatus.called),
        entry(3, MembershipStatus.waiting),
      ];
      expect(QueueRules.customersAhead(entries, 'e3'), 1);
    });

    test('an entry that is not active has no position', () {
      final entries = [entry(1, MembershipStatus.left)];
      expect(QueueRules.positionOf(entries, 'e1'), isNull);
      expect(QueueRules.customersAhead(entries, 'e1'), isNull);
    });

    test('a new ticket is the highest number plus one, finished included', () {
      final entries = [
        entry(1, MembershipStatus.served),
        entry(2, MembershipStatus.left),
        entry(3, MembershipStatus.skipped),
      ];
      expect(QueueRules.nextTicketNumber(entries), 4);
      expect(QueueRules.nextTicketNumber(const []), 1);
    });
  });

  group('near turn', () {
    test('is true for a waiting customer with two ahead', () {
      expect(
        QueueRules.isNearTurn(
          entry: entry(3, MembershipStatus.waiting),
          customersAhead: 2,
        ),
        isTrue,
      );
    });

    test('is false with one or three ahead, or when called', () {
      final waiting = entry(3, MembershipStatus.waiting);
      expect(QueueRules.isNearTurn(entry: waiting, customersAhead: 1), isFalse);
      expect(QueueRules.isNearTurn(entry: waiting, customersAhead: 3), isFalse);
      expect(
        QueueRules.isNearTurn(
          entry: entry(3, MembershipStatus.called),
          customersAhead: 2,
        ),
        isFalse,
      );
    });
  });

  group('join', () {
    test('accepts a customer without a ticket in an open queue', () {
      final result = QueueRules.checkJoin(
        user: customer,
        queue: openQueue,
        hasActiveMembership: false,
      );
      expect(result.isOk, isTrue);
    });

    test('rejects signed-out users, providers and missing queues', () {
      expect(
        QueueRules.checkJoin(
          user: null,
          queue: openQueue,
          hasActiveMembership: false,
        ).error,
        OperationError.notSignedIn,
      );
      expect(
        QueueRules.checkJoin(
          user: provider,
          queue: openQueue,
          hasActiveMembership: false,
        ).error,
        OperationError.wrongRole,
      );
      expect(
        QueueRules.checkJoin(
          user: customer,
          queue: null,
          hasActiveMembership: false,
        ).error,
        OperationError.queueNotFound,
      );
    });

    test('rejects a closed queue and a second active membership', () {
      const closed = ServiceQueue(
        id: 'q2',
        providerId: 'p2',
        name: 'Closed',
        description: '',
        averageServiceMinutes: 5,
        isOpen: false,
      );
      expect(
        QueueRules.checkJoin(
          user: customer,
          queue: closed,
          hasActiveMembership: false,
        ).error,
        OperationError.queueClosed,
      );
      expect(
        QueueRules.checkJoin(
          user: customer,
          queue: openQueue,
          hasActiveMembership: true,
        ).error,
        OperationError.alreadyMember,
      );
    });
  });

  group('leave', () {
    test('only a waiting ticket can leave', () {
      expect(
        QueueRules.checkLeave(entry(1, MembershipStatus.waiting)).isOk,
        isTrue,
      );
      for (final status in [
        MembershipStatus.called,
        MembershipStatus.served,
        MembershipStatus.skipped,
        MembershipStatus.left,
      ]) {
        expect(
          QueueRules.checkLeave(entry(1, status)).error,
          OperationError.notWaiting,
        );
      }
      expect(QueueRules.checkLeave(null).error, OperationError.notWaiting);
    });
  });

  group('provider actions', () {
    test('Call Next needs a waiting customer and nobody called', () {
      expect(
        QueueRules.checkCallNext([entry(1, MembershipStatus.waiting)]).isOk,
        isTrue,
      );
      expect(
        QueueRules.checkCallNext(const []).error,
        OperationError.nobodyWaiting,
      );
      expect(
        QueueRules.checkCallNext([
          entry(1, MembershipStatus.called),
          entry(2, MembershipStatus.waiting),
        ]).error,
        OperationError.alreadyCalled,
      );
    });

    test('Served and Skip need a called customer', () {
      expect(
        QueueRules.checkFinishCalled([entry(1, MembershipStatus.called)]).isOk,
        isTrue,
      );
      expect(
        QueueRules.checkFinishCalled([
          entry(1, MembershipStatus.waiting),
        ]).error,
        OperationError.nothingCalled,
      );
    });

    test('creating a queue needs a provider, a name and positive minutes', () {
      expect(
        QueueRules.checkCreateQueue(
          user: provider,
          hasQueue: false,
          name: 'Barber',
          averageServiceMinutes: 5,
        ).isOk,
        isTrue,
      );
      expect(
        QueueRules.checkCreateQueue(
          user: provider,
          hasQueue: true,
          name: 'Barber',
          averageServiceMinutes: 5,
        ).error,
        OperationError.hasQueue,
      );
      expect(
        QueueRules.checkCreateQueue(
          user: provider,
          hasQueue: false,
          name: '  ',
          averageServiceMinutes: 5,
        ).error,
        OperationError.invalidInput,
      );
      expect(
        QueueRules.checkCreateQueue(
          user: provider,
          hasQueue: false,
          name: 'Barber',
          averageServiceMinutes: 0,
        ).error,
        OperationError.invalidInput,
      );
      expect(
        QueueRules.checkCreateQueue(
          user: customer,
          hasQueue: false,
          name: 'Barber',
          averageServiceMinutes: 5,
        ).error,
        OperationError.wrongRole,
      );
    });
  });
}