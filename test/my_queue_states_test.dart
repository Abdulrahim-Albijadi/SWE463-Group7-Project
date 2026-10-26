import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/screens/customer/my_queue_screen.dart';

void main() {
  late QueueDemoState state;

  setUp(() {
    state = QueueDemoState();
    state.signInAs(UserRole.customer);
  });

  tearDown(() {
    state.dispose();
  });

  Future<void> showQueue(
    WidgetTester tester, {
    bool isLoading = false,
    String? errorMessage,
    VoidCallback? onRetry,
    bool isLeaving = false,
    String? leaveErrorMessage,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MyQueueScreen(
          state: state,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry,
          isLeaving: isLeaving,
          leaveErrorMessage: leaveErrorMessage,
        ),
      ),
    );
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

  testWidgets('Loading hides ticket data and takes priority over errors', (
    tester,
  ) async {
    await showQueue(tester, isLoading: true, errorMessage: 'Previous error');

    expect(find.text('Loading your ticket...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('#12'), findsNothing);
    expect(find.text('Leave Queue'), findsNothing);
    expect(find.text('Previous error'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Load error hides ticket and Retry invokes callback', (
    tester,
  ) async {
    var retries = 0;

    await showQueue(
      tester,
      errorMessage: 'Could not load your ticket.',
      onRetry: () => retries++,
    );

    expect(find.text('Could not load your ticket.'), findsOneWidget);
    expect(find.text('#12'), findsNothing);
    expect(find.text('Leave Queue'), findsNothing);

    final retry = find.widgetWithText(FilledButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('Leaving disables the button and hides previous leave error', (
    tester,
  ) async {
    final ticket = state.myActiveEntry;

    await showQueue(
      tester,
      isLeaving: true,
      leaveErrorMessage: 'Previous leave error',
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Previous leave error'), findsNothing);

    final button = find.widgetWithText(OutlinedButton, 'Leaving...');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    expect(find.byType(AlertDialog), findsNothing);
    expect(state.myActiveEntry, same(ticket));
    expect(ticket!.status, MembershipStatus.waiting);
  });

  testWidgets('Cancelling Leave preserves the active ticket', (tester) async {
    final ticket = state.myActiveEntry;

    await showQueue(tester);
    await openLeaveDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(state.myActiveEntry, same(ticket));
    expect(ticket!.status, MembershipStatus.waiting);
  });

  testWidgets('Leave error allows confirmation and successful departure', (
    tester,
  ) async {
    final ticket = state.myActiveEntry;

    await showQueue(tester, leaveErrorMessage: 'Please try leaving again.');

    expect(find.text('Could not leave the queue'), findsOneWidget);
    expect(find.text('Please try leaving again.'), findsOneWidget);

    await openLeaveDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Leave Queue'));
    await tester.pumpAndSettle();

    expect(state.myActiveEntry, isNull);
    expect(ticket!.status, MembershipStatus.left);
    expect(find.text('You left the queue.'), findsOneWidget);
    expect(find.text('Could not leave the queue'), findsNothing);
  });

  testWidgets('Customer without entries sees the empty state', (tester) async {
    state.entries.removeWhere(
      (entry) => entry.customerId == state.currentUser!.id,
    );

    await showQueue(tester);

    expect(find.text('No Active Queue'), findsOneWidget);
    expect(find.text('Browse Queues'), findsOneWidget);
    expect(find.text('Leave Queue'), findsNothing);
    expect(find.text('YOUR TICKET NUMBER'), findsNothing);
  });
}
