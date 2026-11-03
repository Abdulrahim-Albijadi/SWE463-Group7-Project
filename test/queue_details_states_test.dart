import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/providers/membership_provider.dart';
import 'package:swe463_group7_project/providers/queue_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/screens/customer/queue_details_screen.dart';

class ControlledQueueRepository extends QueueRepository {
  Completer<OperationResult>? joinGate;
  bool failLoading = false;
  int joinRequests = 0;
  int loadRequests = 0;

  @override
  Stream<List<QueueSummary>> watchQueueSummaries() {
    loadRequests++;
    if (failLoading) {
      return Stream<List<QueueSummary>>.error(StateError('offline'));
    }
    return super.watchQueueSummaries();
  }

  @override
  Future<OperationResult> join({
    required AppUser customer,
    required String queueId,
  }) async {
    joinRequests++;

    final gate = joinGate;
    if (gate != null) {
      final result = await gate.future;
      if (!result.isOk) return result;
    }

    return super.join(customer: customer, queueId: queueId);
  }
}

void main() {
  Future<MembershipProvider> showDetails(
    WidgetTester tester, {
    required ControlledQueueRepository repository,
    bool keepActiveTicket = false,
    bool selectQueue = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authRepository = AuthRepository();
    final outcome = await authRepository.signIn(
      email: 'customer@example.com',
      password: 'demopass',
    );

    if (!keepActiveTicket) {
      await repository.leave(customer: outcome.user!, entryId: 'e12');
    }

    await tester.pumpWidget(
      AppProviders(
        authRepository: authRepository,
        queueRepository: repository,
        child: MaterialApp(
          home: const QueueDetailsScreen(),
          routes: {
            '/my-queue': (_) =>
                const Scaffold(body: Text('Ticket destination')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(QueueDetailsScreen));

    if (selectQueue) {
      context.read<QueueProvider>().select('campus-barber');
      await tester.pumpAndSettle();
    }

    return context.read<MembershipProvider>();
  }

  Future<void> tapJoin(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Join Queue');

    await tester.scrollUntilVisible(
      button.hitTestable(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(button.hitTestable());
  }

  testWidgets('Pending join is disabled and a failed join can be retried', (
    tester,
  ) async {
    final repository = ControlledQueueRepository();
    final gate = Completer<OperationResult>();
    repository.joinGate = gate;

    final membership = await showDetails(tester, repository: repository);

    await tapJoin(tester);
    await tester.pump();

    expect(membership.isJoining, isTrue);
    expect(repository.joinRequests, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final joining = find.widgetWithText(FilledButton, 'Joining...');
    expect(tester.widget<FilledButton>(joining).onPressed, isNull);

    gate.complete(OperationResult.failure(OperationError.failed));
    await tester.pumpAndSettle();

    expect(membership.isJoining, isFalse);
    expect(membership.hasActiveMembership, isFalse);
    expect(find.text('Could not join the queue'), findsOneWidget);

    repository.joinGate = null;

    await tapJoin(tester);
    await tester.pumpAndSettle();

    expect(repository.joinRequests, 2);
    expect(membership.hasActiveMembership, isTrue);
    expect(membership.currentEntry!.queueId, 'campus-barber');
    expect(find.text('Ticket destination'), findsOneWidget);
  });

  testWidgets('An active membership prevents another join', (tester) async {
    final repository = ControlledQueueRepository();

    final membership = await showDetails(
      tester,
      repository: repository,
      keepActiveTicket: true,
    );

    final button = find.widgetWithText(FilledButton, 'Cannot Join');

    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('You already have an active ticket'), findsOneWidget);
    expect(membership.currentEntry!.ticketNumber, 12);
    expect(repository.joinRequests, 0);
  });

  testWidgets('Without a selected queue no join action is shown', (
    tester,
  ) async {
    await showDetails(
      tester,
      repository: ControlledQueueRepository(),
      selectQueue: false,
    );

    expect(
      find.text('This queue is unavailable. Return Home and select a queue.'),
      findsOneWidget,
    );
    expect(find.text('Join Queue'), findsNothing);
  });

  testWidgets('Retry recovers queue details after a load error', (
    tester,
  ) async {
    final repository = ControlledQueueRepository()..failLoading = true;

    await showDetails(tester, repository: repository);

    expect(find.text('Campus Barber'), findsNothing);
    expect(find.text('Join Queue'), findsNothing);
    expect(repository.loadRequests, 1);

    repository.failLoading = false;

    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.loadRequests, 2);
    expect(find.text('Campus Barber'), findsOneWidget);
    expect(find.text('Join Queue'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
