import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/providers/membership_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/screens/customer/my_queue_screen.dart';

class ControlledMembershipRepository extends QueueRepository {
  ControlledMembershipRepository({super.seedSampleData = true});

  bool holdTicket = false;
  bool failTicketLoading = false;
  int ticketRequests = 0;
  int leaveRequests = 0;
  Completer<OperationResult>? leaveGate;

  @override
  Stream<QueueEntry?> watchLatestEntryOfCustomer(String customerId) {
    ticketRequests++;

    if (holdTicket) {
      return const Stream<QueueEntry?>.empty();
    }
    if (failTicketLoading) {
      return Stream<QueueEntry?>.error(StateError('offline'));
    }

    return super.watchLatestEntryOfCustomer(customerId);
  }

  @override
  Future<OperationResult> leave({
    required AppUser customer,
    required String entryId,
  }) async {
    leaveRequests++;

    final gate = leaveGate;
    if (gate != null) {
      final result = await gate.future;
      if (!result.isOk) return result;
    }

    return super.leave(customer: customer, entryId: entryId);
  }
}

void main() {
  Future<MembershipProvider> showQueue(
    WidgetTester tester,
    ControlledMembershipRepository repository,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authRepository = AuthRepository();
    await authRepository.signIn(
      email: 'customer@example.com',
      password: 'demopass',
    );

    await tester.pumpWidget(
      AppProviders(
        authRepository: authRepository,
        queueRepository: repository,
        child: const MaterialApp(home: MyQueueScreen()),
      ),
    );

    if (repository.holdTicket) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }

    return tester
        .element(find.byType(MyQueueScreen))
        .read<MembershipProvider>();
  }

  Future<void> openLeaveDialog(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Leave Queue');

    await tester.scrollUntilVisible(
      button.hitTestable(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(button.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Leave queue?'), findsOneWidget);
  }

  testWidgets('Loading hides ticket data and keeps navigation', (tester) async {
    final repository = ControlledMembershipRepository()..holdTicket = true;

    await showQueue(tester, repository);

    expect(find.text('Loading your ticket...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('#12'), findsNothing);
    expect(find.text('Leave Queue'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Retry recovers the ticket after a loading error', (
    tester,
  ) async {
    final repository = ControlledMembershipRepository()
      ..failTicketLoading = true;

    await showQueue(tester, repository);

    expect(find.text('#12'), findsNothing);
    expect(find.text('Leave Queue'), findsNothing);
    expect(repository.ticketRequests, 1);

    repository.failTicketLoading = false;

    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.ticketRequests, 2);
    expect(find.text('#12'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Cancelling Leave preserves membership without a request', (
    tester,
  ) async {
    final repository = ControlledMembershipRepository();
    final membership = await showQueue(tester, repository);
    final ticketId = membership.currentEntry!.id;

    await openLeaveDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.leaveRequests, 0);
    expect(membership.currentEntry!.id, ticketId);
    expect(membership.isWaiting, isTrue);
  });

  testWidgets('Pending departure is disabled and a failure can be retried', (
    tester,
  ) async {
    final repository = ControlledMembershipRepository();
    final gate = Completer<OperationResult>();
    repository.leaveGate = gate;

    final membership = await showQueue(tester, repository);

    await openLeaveDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Leave Queue'));

    // Close the dialog animation without waiting for the progress indicator.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(membership.isLeaving, isTrue);
    expect(repository.leaveRequests, 1);

    final leaving = find.widgetWithText(OutlinedButton, 'Leaving...');
    expect(tester.widget<OutlinedButton>(leaving).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(OperationResult.failure(OperationError.failed));
    await tester.pumpAndSettle();

    expect(membership.isLeaving, isFalse);
    expect(membership.hasActiveMembership, isTrue);
    expect(find.text('Could not leave the queue'), findsOneWidget);

    // Dismiss the failure feedback before testing the next button press.
    ScaffoldMessenger.of(tester.element(find.byType(MyQueueScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    repository.leaveGate = null;

    await openLeaveDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Leave Queue'));
    await tester.pumpAndSettle();

    expect(repository.leaveRequests, 2);
    expect(membership.hasActiveMembership, isFalse);
    expect(membership.currentEntry!.status, MembershipStatus.left);
    expect(find.text('You left the queue.'), findsOneWidget);
    expect(find.text('Could not leave the queue'), findsNothing);
  });

  testWidgets('Customer without entries sees the empty state', (tester) async {
    final repository = ControlledMembershipRepository(seedSampleData: false);

    await showQueue(tester, repository);

    expect(find.text('No Active Queue'), findsOneWidget);
    expect(find.text('Browse Queues'), findsOneWidget);
    expect(find.text('Leave Queue'), findsNothing);
    expect(find.text('YOUR TICKET NUMBER'), findsNothing);
  });

  testWidgets('Called customer sees the called state without Leave', (
    tester,
  ) async {
    final repository = ControlledMembershipRepository();
    const provider = AppUser(
      id: 'provider-1',
      name: 'Campus Barber Owner',
      email: 'provider@example.com',
      role: UserRole.provider,
    );

    // Finish tickets 9, 10 and 11, calling the next customer each time.
    for (var i = 0; i < 3; i++) {
      final served = await repository.finishCalled(
        provider: provider,
        queueId: 'campus-barber',
        outcome: MembershipStatus.served,
      );
      expect(served.isOk, isTrue);

      final called = await repository.callNext(
        provider: provider,
        queueId: 'campus-barber',
      );
      expect(called.isOk, isTrue);
    }

    final membership = await showQueue(tester, repository);

    expect(membership.isCalled, isTrue);
    expect(find.text('#12'), findsOneWidget);
    expect(find.text('Called'), findsOneWidget);
    expect(find.text('Leave Queue'), findsNothing);
    expect(repository.leaveRequests, 0);
  });

  testWidgets('Leave confirmation preserves a replacement ticket', (
    tester,
  ) async {
    final repository = ControlledMembershipRepository();
    final membership = await showQueue(tester, repository);
    final originalEntry = membership.currentEntry!;

    await openLeaveDialog(tester);

    final customer = AppUser(
      id: originalEntry.customerId,
      name: originalEntry.customerName,
      email: 'customer@example.com',
      role: UserRole.customer,
    );

    // Simulate leaving and rejoining from another session.
    await repository.leave(customer: customer, entryId: originalEntry.id);
    await repository.join(customer: customer, queueId: originalEntry.queueId);
    await tester.pumpAndSettle();

    final replacementId = membership.currentEntry!.id;
    expect(replacementId, isNot(originalEntry.id));

    final requestsBeforeConfirm = repository.leaveRequests;

    await tester.tap(find.widgetWithText(TextButton, 'Leave Queue'));
    await tester.pumpAndSettle();

    expect(repository.leaveRequests, requestsBeforeConfirm);
    expect(membership.currentEntry!.id, replacementId);
    expect(membership.isWaiting, isTrue);
    expect(
      find.text('Your ticket has changed. Review its status before leaving.'),
      findsOneWidget,
    );
  });

  testWidgets('Waiting ticket shows its current position', (tester) async {
    await showQueue(tester, ControlledMembershipRepository());

    expect(find.text('#12'), findsOneWidget);
    expect(find.text('Current position: 4'), findsOneWidget);
  });

  for (final ahead in [0, 1, 2, 3]) {
    testWidgets('Near-turn notice with $ahead customers ahead', (tester) async {
      final repository = ControlledMembershipRepository();
      const provider = AppUser(
        id: 'provider-1',
        name: 'Campus Barber Owner',
        email: 'provider@example.com',
        role: UserRole.provider,
      );

      // The sample customer starts with three customers ahead.
      final customersToServe = 3 - ahead;
      for (var i = 0; i < customersToServe; i++) {
        final served = await repository.finishCalled(
          provider: provider,
          queueId: 'campus-barber',
          outcome: MembershipStatus.served,
        );
        expect(served.isOk, isTrue);

        if (i < customersToServe - 1) {
          final called = await repository.callNext(
            provider: provider,
            queueId: 'campus-barber',
          );
          expect(called.isOk, isTrue);
        }
      }

      final membership = await showQueue(tester, repository);

      expect(membership.isWaiting, isTrue);
      expect(membership.customersAhead, ahead);

      const nearMessage = 'Your turn is near. Please be ready.';
      const waitingMessage = 'We’ll notify you when your turn is near.';
      final expectedMessage = ahead <= 2 ? nearMessage : waitingMessage;
      final unexpectedMessage = ahead <= 2 ? waitingMessage : nearMessage;

      await tester.scrollUntilVisible(
        find.text(expectedMessage),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(expectedMessage), findsOneWidget);
      expect(find.text(unexpectedMessage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('My Queue fits a narrow screen with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthRepository();
    await auth.signIn(email: 'customer@example.com', password: 'demopass');

    await tester.pumpWidget(
      AppProviders(
        authRepository: auth,
        queueRepository: QueueRepository(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const MyQueueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#12'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var step = 0; step < 20; step++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    expect(
      find.widgetWithText(OutlinedButton, 'Leave Queue').hitTestable(),
      findsOneWidget,
    );
  });
}
