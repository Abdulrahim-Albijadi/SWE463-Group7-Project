import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/screens/customer/customer_home_screen.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';

class FailingQueueRepository extends QueueRepository {
  int requests = 0;

  @override
  Stream<List<QueueSummary>> watchQueueSummaries() {
    requests++;
    return Stream<List<QueueSummary>>.error(StateError('offline'));
  }
}

void main() {
  Future<void> showHome(
    WidgetTester tester, {
    QueueRepository? queueRepository,
    bool settle = true,
  }) async {
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
        queueRepository: queueRepository ?? QueueRepository(),
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('Loading hides queue data and keeps navigation', (tester) async {
    await showHome(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading queues...'), findsOneWidget);
    expect(find.text('Campus Barber'), findsNothing);
    expect(find.text('View Queue'), findsNothing);
    expect(find.text('View My Ticket'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Queue'), findsOneWidget);
  });

  testWidgets('Error hides queue data and Retry loads again', (tester) async {
    final repository = FailingQueueRepository();

    await showHome(tester, queueRepository: repository);

    expect(find.text('Campus Barber'), findsNothing);
    expect(find.text('View Queue'), findsNothing);
    expect(find.text('View My Ticket'), findsNothing);
    expect(repository.requests, 1);

    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.requests, 2);
  });

  // testWidgets('Retry is disabled without a callback', (tester) async {
  //   await showHome(tester, errorMessage: 'Could not load queues.');

  //   final retry = tester.widget<FilledButton>(
  //     find.widgetWithText(FilledButton, 'Retry'),
  //   );

  //   expect(retry.onPressed, isNull);
  // });

  testWidgets('No queue displays the empty state', (tester) async {
    await showHome(
      tester,
      queueRepository: QueueRepository(seedSampleData: false),
    );

    expect(
      find.text('No queues available right now.\nPlease check again later.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('View Queue'), findsNothing);
    expect(find.text('View My Ticket'), findsNothing);
  });

  testWidgets('Default state preserves the existing queue display', (
    tester,
  ) async {
    await showHome(tester);

    expect(find.text('Campus Barber'), findsOneWidget);
    expect(find.text('View My Ticket'), findsOneWidget);
    expect(find.text('Loading queues...'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
}
