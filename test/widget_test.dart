import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/main.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';

void main() {
  for (final (account, homeTitle) in [
    ('customer@example.com', 'Available Queues'),
    ('provider@example.com', 'Provider Dashboard'),
  ]) {
    testWidgets('Restored session opens $homeTitle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = AuthRepository();
      await auth.signIn(email: account, password: 'demopass');

      await tester.pumpWidget(
        AppProviders(
          authRepository: auth,
          queueRepository: QueueRepository(),
          child: const QueueLessApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(homeTitle), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(
        Navigator.of(tester.element(find.text(homeTitle))).canPop(),
        false,
      );
    });
  }

  testWidgets('Customer can sign in and open their ticket', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppProviders(
        authRepository: AuthRepository(),
        queueRepository: QueueRepository(),
        child: const QueueLessApp(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      isEmpty,
    );
    await tester.enterText(fields.at(0), 'customer@example.com');
    await tester.enterText(fields.at(1), 'demopass');

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
