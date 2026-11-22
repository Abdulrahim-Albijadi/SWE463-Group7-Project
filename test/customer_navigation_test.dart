import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/widgets/customer/customer_widgets.dart';

void main() {
  Future<void> showPage(WidgetTester tester, {required int selected}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerPage(
          title: selected == 0 ? 'Queue Details' : 'My Queue',
          selected: selected,
          back: true,
          children: const [],
        ),
        routes: {
          '/customer': (_) =>
              const Scaffold(body: Text('Customer Home destination')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home tab works from Queue Details', (tester) async {
    await showPage(tester, selected: 0);

    await tester.tap(find.byType(NavigationDestination).first);
    await tester.pumpAndSettle();

    expect(find.text('Customer Home destination'), findsOneWidget);
  });

  for (final selected in [0, 1]) {
    final screen = selected == 0 ? 'Queue Details' : 'My Queue';

    testWidgets('System Back from $screen returns Home', (tester) async {
      await showPage(tester, selected: selected);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Customer Home destination'), findsOneWidget);
    });
  }
}
