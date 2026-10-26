import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/screens/customer/queue_details_screen.dart';

void main() {
  late QueueDemoState state;

  setUp(() {
    state = QueueDemoState();
    state.signInAs(UserRole.customer);
    state.leaveQueue();
  });

  tearDown(() {
    state.dispose();
  });

  Future<void> showDetails(
    WidgetTester tester, {
    bool isJoining = false,
    String? joinErrorMessage,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: QueueDetailsScreen(
          state: state,
          isJoining: isJoining,
          joinErrorMessage: joinErrorMessage,
        ),
        routes: {
          '/my-queue': (_) => const Scaffold(body: Text('Ticket destination')),
        },
      ),
    );
  }

  testWidgets('Joining disables the button and hides the previous error', (
    tester,
  ) async {
    await showDetails(
      tester,
      isJoining: true,
      joinErrorMessage: 'Previous failure',
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Previous failure'), findsNothing);

    final button = find.widgetWithText(FilledButton, 'Joining...');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(state.myActiveEntry, isNull);
    expect(find.text('Ticket destination'), findsNothing);
  });

  testWidgets('Join error allows another attempt and successful navigation', (
    tester,
  ) async {
    await showDetails(tester, joinErrorMessage: 'Please try again.');

    expect(find.text('Could not join the queue'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final button = find.widgetWithText(FilledButton, 'Join Queue');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(state.myActiveEntry, isNotNull);
    expect(state.myActiveEntry!.status, MembershipStatus.waiting);
    expect(find.text('Ticket destination'), findsOneWidget);
  });

  testWidgets('An active ticket prevents a second join', (tester) async {
    state.joinQueue();
    final entryCount = state.entries.length;

    await showDetails(tester);

    final button = find.widgetWithText(FilledButton, 'Cannot Join');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('You already have an active ticket'), findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(state.entries.length, entryCount);
  });

  testWidgets('Unavailable queue has no join action', (tester) async {
    state.queue = null;

    await showDetails(tester);

    expect(find.text('This queue is unavailable.'), findsOneWidget);
    expect(find.text('Join Queue'), findsNothing);
    expect(find.text('Joining...'), findsNothing);
  });
}
