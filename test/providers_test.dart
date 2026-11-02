import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/auth_provider.dart';
import 'package:swe463_group7_project/providers/membership_provider.dart';
import 'package:swe463_group7_project/providers/provider_queue_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';

const provider = AppUser(
  id: 'p1',
  name: 'Provider',
  email: 'p1@example.com',
  role: UserRole.provider,
);

AppUser customer(int number) => AppUser(
  id: 'c$number',
  name: 'Customer $number',
  email: 'c$number@example.com',
  role: UserRole.customer,
);

Future<(QueueRepository, String)>
createQueueWithThreeCustomers() async {
  final repository = QueueRepository(seedSampleData: false);
  await repository.createQueue(
    provider: provider,
    name: 'Barber',
    description: '',
    averageServiceMinutes: 5,
  );
  final queue = await repository.watchQueueOfProvider('p1').first;
  for (var i = 1; i <= 3; i++) {
    await repository.join(customer: customer(i), queueId: queue!.id);
  }
  return (repository, queue!.id);
}

// Provider tests on the dummy-data repositories: position and wait while the
// ticket stays fixed (10 min, then 5 min), alerts sent once, the served,
// skipped and left outcomes, provider actions, and switching accounts.
void main() {
  test('position and wait change while the ticket stays fixed', () async {
    final (repository, queueId) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(3));
    await pumpEventQueue();

    expect(membership.currentEntry!.ticketNumber, 3);
    expect(membership.customersAhead, 2);
    expect(membership.estimatedWaitMinutes, 10);

    // Calling customer 1 leaves both values unchanged.
    await repository.callNext(provider: provider, queueId: queueId);
    await pumpEventQueue();
    expect(membership.customersAhead, 2);
    expect(membership.estimatedWaitMinutes, 10);

    // Serving customer 1 moves customer 3 forward.
    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.served,
    );
    await pumpEventQueue();
    expect(membership.currentEntry!.ticketNumber, 3);
    expect(membership.customersAhead, 1);
    expect(membership.estimatedWaitMinutes, 5);

    // Customer 2 is called and served, then customer 3 is called.
    await repository.callNext(provider: provider, queueId: queueId);
    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.served,
    );
    await repository.callNext(provider: provider, queueId: queueId);
    await pumpEventQueue();
    expect(membership.isCalled, isTrue);
    expect(membership.customersAhead, 0);

    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.served,
    );
    await pumpEventQueue();
    expect(membership.currentEntry!.status, MembershipStatus.served);
    expect(membership.hasActiveMembership, isFalse);
    expect(membership.position, isNull);
    membership.dispose();
  });

  test('near turn is shown at two ahead and is not a status', () async {
    final (repository, _) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(3));
    await pumpEventQueue();
    expect(membership.isNearTurn, isTrue);
    expect(membership.currentEntry!.status, MembershipStatus.waiting);
    membership.dispose();
  });

  test('each alert is sent only once', () async {
    final (repository, queueId) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository);
    final alerts = <QueueNotification>[];
    membership.alerts.listen(alerts.add);
    membership.bindUser(customer(3));
    await pumpEventQueue();
    expect(alerts.map((a) => a.type), [NotificationType.nearTurn]);

    // Updates that keep the customer near their turn do not repeat the alert.
    await repository.callNext(provider: provider, queueId: queueId);
    await pumpEventQueue();
    expect(alerts.length, 1);

    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.served,
    );
    await repository.callNext(provider: provider, queueId: queueId);
    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.served,
    );
    await repository.callNext(provider: provider, queueId: queueId);
    await pumpEventQueue();
    expect(alerts.map((a) => a.type), [
      NotificationType.nearTurn,
      NotificationType.called,
    ]);
    membership.dispose();
  });

  test('joining gives a ticket and a second join is rejected', () async {
    final repository = QueueRepository(seedSampleData: false);
    await repository.createQueue(
      provider: provider,
      name: 'Barber',
      description: '',
      averageServiceMinutes: 5,
    );
    final queue = await repository.watchQueueOfProvider('p1').first;
    final membership = MembershipProvider(repository)..bindUser(customer(1));
    await pumpEventQueue();
    expect(membership.currentEntry, isNull);

    final first = await membership.join(queue!.id);
    await pumpEventQueue();
    final second = await membership.join(queue.id);

    expect(first.isOk, isTrue);
    expect(membership.currentEntry!.ticketNumber, 1);
    expect(second.error, OperationError.alreadyMember);
    expect(membership.joinError, isNotNull);
    membership.dispose();
  });

  test('leaving ends the membership and keeps the ticket', () async {
    final (repository, _) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(2));
    await pumpEventQueue();

    final result = await membership.leave();
    await pumpEventQueue();

    expect(result.isOk, isTrue);
    expect(membership.currentEntry!.status, MembershipStatus.left);
    expect(membership.hasActiveMembership, isFalse);
    membership.dispose();
  });

  test('a called customer cannot leave', () async {
    final (repository, queueId) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(1));
    await repository.callNext(provider: provider, queueId: queueId);
    await pumpEventQueue();

    final result = await membership.leave();

    expect(result.error, OperationError.notWaiting);
    expect(membership.currentEntry!.status, MembershipStatus.called);
    membership.dispose();
  });

  test('a skipped customer is no longer active and is not replaced', () async {
    final (repository, queueId) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(1));
    await repository.callNext(provider: provider, queueId: queueId);
    await repository.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: MembershipStatus.skipped,
    );
    await pumpEventQueue();

    expect(membership.currentEntry!.status, MembershipStatus.skipped);
    expect(membership.hasActiveMembership, isFalse);
    final entries = await repository.watchEntries(queueId).first;
    expect(entries[1].status, MembershipStatus.waiting);
    membership.dispose();
  });

  test('a new account never sees the previous account\'s ticket', () async {
    final (repository, _) = await createQueueWithThreeCustomers();
    final membership = MembershipProvider(repository)..bindUser(customer(3));
    await pumpEventQueue();
    expect(membership.currentEntry!.customerId, 'c3');

    membership.bindUser(null);
    await pumpEventQueue();
    expect(membership.currentEntry, isNull);

    membership.bindUser(customer(1));
    await pumpEventQueue();
    expect(membership.currentEntry!.customerId, 'c1');
    expect(membership.currentEntry!.ticketNumber, 1);
    membership.dispose();
  });

  group('ProviderQueueProvider', () {
    test('creates one queue and rejects a second one', () async {
      final repository = QueueRepository(seedSampleData: false);
      final providerQueue = ProviderQueueProvider(repository)
        ..bindUser(provider);
      await pumpEventQueue();
      expect(providerQueue.queue, isNull);

      final empty = await providerQueue.createQueue(
        name: '',
        description: '',
        averageServiceMinutes: 5,
      );
      final first = await providerQueue.createQueue(
        name: 'Barber',
        description: '',
        averageServiceMinutes: 5,
      );
      final second = await providerQueue.createQueue(
        name: 'Second',
        description: '',
        averageServiceMinutes: 5,
      );
      await pumpEventQueue();

      expect(empty.error, OperationError.invalidInput);
      expect(first.isOk, isTrue);
      expect(providerQueue.queue!.averageServiceMinutes, 5);
      expect(second.error, OperationError.hasQueue);
      providerQueue.dispose();
    });

    test('Call Next, Served and Skip follow the provider rules', () async {
      final (repository, _) = await createQueueWithThreeCustomers();
      final providerQueue = ProviderQueueProvider(repository)
        ..bindUser(provider);
      await pumpEventQueue();
      expect(providerQueue.waitingEntries.length, 3);
      expect(providerQueue.canCallNext, isTrue);
      expect(providerQueue.canFinishCalled, isFalse);

      await providerQueue.callNext();
      await pumpEventQueue();
      expect(providerQueue.calledEntry!.ticketNumber, 1);
      expect(providerQueue.canCallNext, isFalse);
      expect(providerQueue.canFinishCalled, isTrue);
      final again = await providerQueue.callNext();
      expect(again.error, OperationError.alreadyCalled);

      await providerQueue.skipCalled();
      await pumpEventQueue();
      expect(providerQueue.calledEntry, isNull);
      expect(providerQueue.waitingEntries.length, 2);

      await providerQueue.callNext();
      await providerQueue.markServed();
      await pumpEventQueue();
      expect(providerQueue.activeEntries.length, 1);
      providerQueue.dispose();
    });
  });

  group('AuthProvider', () {
    test('signs in a seeded account and rejects a wrong password', () async {
      final auth = AuthProvider(AuthRepository());
      await pumpEventQueue();
      expect(auth.status, AuthStatus.signedOut);

      final wrong = await auth.signIn(
        email: 'customer@example.com',
        password: 'wrong',
      );
      expect(wrong.result.error, OperationError.invalidCredentials);
      expect(auth.currentUser, isNull);

      final right = await auth.signIn(
        email: 'customer@example.com',
        password: 'demopass',
      );
      expect(right.isOk, isTrue);
      expect(auth.currentUser!.role, UserRole.customer);
      auth.dispose();
    });

    test('registers, refuses a duplicate email and signs out', () async {
      final auth = AuthProvider(AuthRepository());
      final created = await auth.register(
        name: 'New Provider',
        email: 'new@example.com',
        password: 'secret1',
        role: UserRole.provider,
      );
      expect(created.isOk, isTrue);
      expect(auth.currentUser!.role, UserRole.provider);

      await auth.signOut();
      expect(auth.currentUser, isNull);

      final duplicate = await auth.register(
        name: 'Again',
        email: 'NEW@example.com',
        password: 'secret1',
        role: UserRole.customer,
      );
      expect(duplicate.result.error, OperationError.emailInUse);
      auth.dispose();
    });
  });
}