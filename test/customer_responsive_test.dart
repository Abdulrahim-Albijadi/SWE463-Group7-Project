import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/providers/queue_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/screens/customer/customer_home_screen.dart';
import 'package:swe463_group7_project/screens/customer/queue_details_screen.dart';

void main() {
  for (final screen in [
    const CustomerHomeScreen(),
    const QueueDetailsScreen(),
  ]) {
    testWidgets('${screen.runtimeType} fits narrow screens and large text', (
      tester,
    ) async {
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
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (screen is QueueDetailsScreen) {
        tester
            .element(find.byType(QueueDetailsScreen))
            .read<QueueProvider>()
            .select('campus-barber');
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
        find.text('Campus Barber'),
        120,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();

      expect(find.text('Campus Barber'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (var step = 0; step < 20; step++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
