import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/main.dart';

void main() {
  testWidgets('Customer can sign in and open their ticket', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const QueueLessApp());
    await tester.pumpAndSettle();

    final signIn = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Available Queues'), findsOneWidget);

    final ticketButton = find.widgetWithText(FilledButton, 'View My Ticket');

    await tester.scrollUntilVisible(
      ticketButton.hitTestable(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(ticketButton.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('#12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Customers ahead'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Leave Queue'), findsOneWidget);
  });
}
