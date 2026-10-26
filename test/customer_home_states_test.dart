import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/screens/customer/customer_home_screen.dart';

void main() {
  late QueueDemoState state;

  setUp(() {
    state = QueueDemoState();
    state.signInAs(UserRole.customer);
  });

  tearDown(() {
    state.dispose();
  });

  Future<void> showHome(
    WidgetTester tester, {
    bool isLoading = false,
    String? errorMessage,
    VoidCallback? onRetry,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerHomeScreen(
          state: state,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry,
        ),
      ),
    );
  }

  testWidgets('Loading hides queue data and keeps navigation', (tester) async {
    await showHome(tester, isLoading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading queues...'), findsOneWidget);
    expect(find.text('Campus Barber'), findsNothing);
    expect(find.text('View Queue'), findsNothing);
    expect(find.text('View My Ticket'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Queue'), findsOneWidget);
  });

  testWidgets('Error hides queue data and Retry invokes callback', (
    tester,
  ) async {
    var retryCount = 0;

    await showHome(
      tester,
      errorMessage: 'Could not load queues.',
      onRetry: () => retryCount++,
    );

    expect(find.text('Could not load queues.'), findsOneWidget);
    expect(find.text('Campus Barber'), findsNothing);
    expect(find.text('View Queue'), findsNothing);
    expect(find.text('View My Ticket'), findsNothing);

    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('Retry is disabled without a callback', (tester) async {
    await showHome(tester, errorMessage: 'Could not load queues.');

    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Retry'),
    );

    expect(retry.onPressed, isNull);
  });

  testWidgets('No queue displays the empty state', (tester) async {
    state.queue = null;

    await showHome(tester);

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
