import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/main.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/providers/membership_provider.dart';
import 'package:swe463_group7_project/providers/provider_queue_provider.dart';
import 'package:swe463_group7_project/providers/provider_support.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/screens/provider_screens.dart';
import 'package:swe463_group7_project/widgets/provider/provider_widgets.dart';

class _ControlledRepository extends QueueRepository {
  _ControlledRepository({super.seedSampleData});

  bool failLoading = false;
  bool holdLoading = false;
  bool failEntries = false;
  Object? queueFailure;
  Object? entriesFailure;
  int loadRequests = 0;
  int createRequests = 0;
  int callRequests = 0;
  int finishRequests = 0;
  Completer<OperationResult>? createGate;
  Completer<OperationResult>? callGate;
  Completer<OperationResult>? finishGate;
  StreamController<ServiceQueue?>? queueStream;
  StreamController<List<QueueEntry>>? entriesStream;

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) {
    loadRequests++;
    if (holdLoading) return const Stream.empty();
    if (queueFailure != null) return Stream.error(queueFailure!);
    if (failLoading) return Stream.error(StateError('offline'));
    return queueStream?.stream ?? super.watchQueueOfProvider(providerId);
  }

  @override
  Stream<List<QueueEntry>> watchEntries(String queueId) {
    if (entriesFailure != null) return Stream.error(entriesFailure!);
    if (failEntries) return Stream.error(StateError('offline'));
    return entriesStream?.stream ?? super.watchEntries(queueId);
  }

  @override
  Future<OperationResult> createQueue({
    required AppUser provider,
    required String name,
    required String description,
    required int averageServiceMinutes,
  }) async {
    createRequests++;
    if (createGate != null) {
      final result = await createGate!.future;
      if (!result.isOk) return result;
    }
    return super.createQueue(
      provider: provider,
      name: name,
      description: description,
      averageServiceMinutes: averageServiceMinutes,
    );
  }

  @override
  Future<OperationResult> callNext({
    required AppUser provider,
    required String queueId,
  }) async {
    callRequests++;
    if (callGate != null) {
      final result = await callGate!.future;
      if (!result.isOk) return result;
    }
    return super.callNext(provider: provider, queueId: queueId);
  }

  @override
  Future<OperationResult> finishCalled({
    required AppUser provider,
    required String queueId,
    required MembershipStatus outcome,
  }) async {
    finishRequests++;
    if (finishGate != null) {
      final result = await finishGate!.future;
      if (!result.isOk) return result;
    }
    return super.finishCalled(
      provider: provider,
      queueId: queueId,
      outcome: outcome,
    );
  }
}

const _owner = AppUser(
  id: 'provider-1',
  name: 'Campus Barber Owner',
  email: 'provider@example.com',
  role: UserRole.provider,
);

void main() {
  Future<ProviderQueueProvider> showScreen(
    WidgetTester tester, {
    required QueueRepository repository,
    Widget screen = const ProviderDashboardScreen(),
    Size size = const Size(390, 844),
    double textScale = 1,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = AuthRepository();
    await auth.signIn(email: 'provider@example.com', password: 'demopass');
    await tester.pumpWidget(
      AppProviders(
        authRepository: auth,
        queueRepository: repository,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
          routes: {
            '/provider': (_) => const ProviderDashboardScreen(),
            '/create-queue': (_) => const CreateQueueScreen(),
            '/manage-queue': (_) => const QueueManagementScreen(),
            '/profile': (_) =>
                const Scaffold(body: Text('Profile destination')),
          },
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return tester
        .element(find.byType(screen.runtimeType))
        .read<ProviderQueueProvider>();
  }

  Finder filled(String label) => find.widgetWithText(FilledButton, label);
  Finder outlined(String label) => find.widgetWithText(OutlinedButton, label);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('queue-name')),
      ' Campus Barber ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('queue-description')),
      ' Barber service ',
    );
    await tester.enterText(find.byKey(const ValueKey('queue-minutes')), '5');
  }

  // Indeterminate progress indicators intentionally keep animating while a
  // write is pending, so navigation checks must not wait for all animations.
  Future<void> finishNavigation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  Finder announcement(String text) => find.byWidgetPredicate(
    (widget) => widget is ProviderAnnouncement && widget.message.contains(text),
  );

  FocusNode fieldFocus(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .focusNode!;

  for (final code in ['permission-denied', 'unavailable']) {
    for (final screen in <Widget>[
      const ProviderDashboardScreen(),
      const CreateQueueScreen(),
      const QueueManagementScreen(),
    ]) {
      testWidgets(
        '${screen.runtimeType} recovers from simulated Firebase $code without a write',
        (tester) async {
          final repo = _ControlledRepository()
            ..queueFailure = FirebaseException(
              plugin: 'cloud_firestore',
              code: code,
            );
          final state = await showScreen(
            tester,
            repository: repo,
            screen: screen,
          );
          expect(state.status, LoadStatus.error);
          expect(find.text('Couldn’t load your queue'), findsOneWidget);
          expect(find.text('Campus Barber'), findsNothing);
          expect(state.canCallNext, isFalse);
          expect(state.canFinishCalled, isFalse);
          expect(
            tester.widget<FilledButton>(filled('Retry')).onPressed,
            isNotNull,
          );
          repo.queueFailure = null;
          await tap(tester, filled('Retry'));
          await tester.pumpAndSettle();
          expect(state.status, LoadStatus.ready);
          expect(find.text('Campus Barber'), findsOneWidget);
          expect(repo.loadRequests, 2);
          expect(
            repo.createRequests + repo.callRequests + repo.finishRequests,
            0,
          );
        },
      );
    }

    testWidgets('Management entry-stream $code recovery refreshes data only', (
      tester,
    ) async {
      final repo = _ControlledRepository()
        ..entriesFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
        );
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      expect(state.status, LoadStatus.error);
      expect(find.text('Couldn’t load your queue'), findsOneWidget);
      expect(find.byType(ProviderWaitingCustomer), findsNothing);
      repo.entriesFailure = null;
      await tap(tester, filled('Retry'));
      await tester.pumpAndSettle();
      expect(state.status, LoadStatus.ready);
      expect(find.text('Waiting customers (3)'), findsOneWidget);
      expect(repo.callRequests + repo.finishRequests, 0);
    });
  }

  testWidgets(
    'A simulated permission-denied write is not retried automatically',
    (tester) async {
      final gate = Completer<OperationResult>();
      final repo = _ControlledRepository()..finishGate = gate;
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      await tap(tester, filled('Mark as Served'));
      gate.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Couldn’t mark #09 as served.'),
        findsOneWidget,
      );
      expect(state.calledEntry!.ticketNumber, 9);
      expect(repo.finishRequests, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.finishRequests, 1);
      repo.finishGate = null;
      await tap(tester, filled('Retry update'));
      await tester.pumpAndSettle();
      expect(repo.finishRequests, 2);
      expect(state.calledEntry, isNull);
    },
  );

  testWidgets(
    'A simulated unavailable create preserves input for explicit retry',
    (tester) async {
      final gate = Completer<OperationResult>();
      final repo = _ControlledRepository(seedSampleData: false)
        ..createGate = gate;
      await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      await fillForm(tester);
      await tap(tester, filled('Create Queue'));
      gate.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Creation failed'), findsOneWidget);
      expect(find.text(' Campus Barber '), findsOneWidget);
      expect(repo.createRequests, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.createRequests, 1);
      repo.createGate = null;
      await tap(tester, filled('Retry creation'));
      await tester.pumpAndSettle();
      expect(repo.createRequests, 2);
      expect(find.text('Queue created'), findsOneWidget);
    },
  );

  testWidgets(
    'Queue creation exposes an explicit success live region and separate actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final repo = _ControlledRepository(seedSampleData: false);
        await showScreen(
          tester,
          repository: repo,
          screen: const CreateQueueScreen(),
        );
        await fillForm(tester);
        await tap(tester, filled('Create Queue'));
        await tester.pumpAndSettle();
        final success = tester
            .getSemantics(find.byKey(const ValueKey('queue-creation-result')))
            .getSemanticsData();
        expect(success.flagsCollection.isLiveRegion, isTrue);
        expect(
          success.label,
          contains('Queue created. Campus Barber is ready.'),
        );
        expect(success.label, contains('Manage Queue'));
        final manage = tester
            .getSemantics(filled('Manage Queue'))
            .getSemanticsData();
        expect(manage.flagsCollection.isButton, isTrue);
        expect(manage.hasAction(SemanticsAction.tap), isTrue);
        expect(manage.flagsCollection.isLiveRegion, isFalse);
        expect(repo.createRequests, 1);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'A saved queue with delayed details announces success without claiming join readiness',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final stream = StreamController<ServiceQueue?>.broadcast();
      addTearDown(() {
        unawaited(stream.close());
      });
      try {
        final repo = _ControlledRepository(seedSampleData: false)
          ..queueStream = stream;
        await showScreen(
          tester,
          repository: repo,
          screen: const CreateQueueScreen(),
          settle: false,
        );
        await tester.pump();
        stream.add(null);
        await tester.pumpAndSettle();
        await fillForm(tester);
        await tap(tester, filled('Create Queue'));
        await finishNavigation(tester);
        final result = tester
            .getSemantics(find.byKey(const ValueKey('queue-creation-result')))
            .getSemanticsData();
        expect(result.flagsCollection.isLiveRegion, isTrue);
        expect(result.label, contains('Queue created. Your queue was saved.'));
        expect(result.label, contains('Waiting for the latest queue details'));
        expect(result.label, isNot(contains('Customers can now join')));
        expect(repo.createRequests, 1);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Load errors announce recovery instructions and retain a labeled retry button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final repo = _ControlledRepository()..failLoading = true;
        await showScreen(tester, repository: repo);
        final error = tester
            .getSemantics(announcement('Couldn’t load your queue'))
            .getSemanticsData();
        expect(error.flagsCollection.isLiveRegion, isTrue);
        expect(error.label, contains('Check your connection'));
        expect(error.label, contains('does not repeat queue actions'));
        final retry = tester.getSemantics(filled('Retry')).getSemanticsData();
        expect(retry.flagsCollection.isButton, isTrue);
        expect(retry.label, 'Retry loading your queue');
        expect(retry.hasAction(SemanticsAction.tap), isTrue);
        repo.failLoading = false;
        await tap(tester, filled('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Couldn’t load your queue'), findsNothing);
        expect(repo.loadRequests, 2);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Loading has one stable live message and profile remains accessible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await showScreen(
          tester,
          repository: _ControlledRepository()..holdLoading = true,
          settle: false,
        );
        await tester.pump();
        final loadingNode = tester.getSemantics(
          announcement('Loading your queue.'),
        );
        final loadingId = loadingNode.id;
        final loading = loadingNode.getSemanticsData();
        expect(loading.flagsCollection.isLiveRegion, isTrue);
        expect(loading.label, contains('Please wait'));
        await tester.pump(const Duration(seconds: 2));
        expect(
          loadingId,
          tester.getSemantics(announcement('Loading your queue.')).id,
        );
        final profile = tester
            .getSemantics(find.byTooltip('Profile'))
            .getSemanticsData();
        expect(profile.flagsCollection.isButton, isTrue);
        expect(profile.tooltip, 'Profile');
        expect(profile.label, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Action error, retry, and success have readable live semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final gate = Completer<OperationResult>();
      final repo = _ControlledRepository()..finishGate = gate;
      await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      await tap(tester, outlined('Skip'));
      gate.complete(OperationResult.failure(OperationError.failed));
      await tester.pumpAndSettle();
      final failure = tester
          .getSemantics(announcement('Couldn’t skip'))
          .getSemanticsData();
      expect(failure.flagsCollection.isLiveRegion, isTrue);
      expect(failure.label, contains('Ahmed Ali is still called'));
      final retry = tester
          .getSemantics(outlined('Retry skip'))
          .getSemanticsData();
      expect(retry.flagsCollection.isButton, isTrue);
      expect(retry.label, 'Retry skipping called customer');
      repo.finishGate = null;
      await tap(tester, outlined('Retry skip'));
      await tester.pumpAndSettle();
      final success = tester
          .getSemantics(announcement('Ahmed Ali — Skipped'))
          .getSemanticsData();
      expect(success.flagsCollection.isLiveRegion, isTrue);
      expect(success.label, contains('No customer auto-called'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Form Next, Tab and Shift Tab follow the field and action order',
    (tester) async {
      await showScreen(
        tester,
        repository: QueueRepository(seedSampleData: false),
        screen: const CreateQueueScreen(),
      );
      final name = find.byKey(const ValueKey('queue-name'));
      final description = find.byKey(const ValueKey('queue-description'));
      final minutes = find.byKey(const ValueKey('queue-minutes'));
      await tester.tap(name);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(fieldFocus(tester, description).hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(fieldFocus(tester, minutes).hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(fieldFocus(tester, description).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(fieldFocus(tester, minutes).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<FilledButton>(),
        isNotNull,
      );
    },
  );

  testWidgets(
    'Keyboard Done creates once and validation focuses the first invalid field',
    (tester) async {
      final repo = _ControlledRepository(seedSampleData: false);
      await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      await tap(tester, filled('Create Queue'));
      await tester.pumpAndSettle();
      expect(
        fieldFocus(tester, find.byKey(const ValueKey('queue-name'))).hasFocus,
        isTrue,
      );
      expect(find.text('Queue name is required.'), findsOneWidget);
      expect(repo.createRequests, 0);
      await fillForm(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Queue created'), findsOneWidget);
      expect(repo.createRequests, 1);
    },
  );

  testWidgets(
    'Keyboard activation opens management and follows Served then Skip',
    (tester) async {
      final repo = _ControlledRepository();
      await showScreen(tester, repository: repo);
      FilledButton? focusedFilled() => FocusManager
          .instance
          .primaryFocus
          ?.context
          ?.findAncestorWidgetOfExactType<FilledButton>();
      Future<void> tabTo(String label) async {
        for (var attempt = 0; attempt < 12; attempt++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final child = focusedFilled()?.child;
          if (child is Text && child.data == label) return;
        }
        fail('Keyboard focus did not reach $label.');
      }

      await tabTo('Manage Queue');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(QueueManagementScreen), findsOneWidget);
      await tabTo('Mark as Served');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final skip = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<OutlinedButton>();
      expect((skip?.child as Text?)?.data, 'Skip');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect((focusedFilled()?.child as Text?)?.data, 'Mark as Served');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('#09 Ahmed Ali — Served'), findsOneWidget);
      expect(repo.finishRequests, 1);
      expect(repo.callRequests, 0);
    },
  );

  for (final screen in <Widget>[
    const ProviderDashboardScreen(),
    const CreateQueueScreen(),
    const QueueManagementScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} has 48px controls and supports 250% text at 280px',
      (tester) async {
        await showScreen(
          tester,
          repository: QueueRepository(
            seedSampleData: screen is! CreateQueueScreen,
          ),
          screen: screen,
          size: const Size(280, 640),
          textScale: 2.5,
        );
        expect(tester.takeException(), isNull);
        final labels = screen is CreateQueueScreen
            ? ['Create Queue', 'Cancel']
            : screen is QueueManagementScreen
            ? ['Mark as Served', 'Skip', 'Call Next']
            : ['Manage Queue'];
        for (final label in labels) {
          final control = label == 'Skip' || label == 'Cancel'
              ? outlined(label)
              : filled(label);
          await tester.scrollUntilVisible(
            control,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        final profile = tester.getSize(find.byTooltip('Profile'));
        expect(profile.width, greaterThanOrEqualTo(48));
        expect(profile.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<_ControlledRepository> longQueue({bool longNames = false}) async {
    final repo = _ControlledRepository(seedSampleData: false);
    final created = await repo.createQueue(
      provider: _owner,
      name: 'Campus Barber',
      description: 'Barber service',
      averageServiceMinutes: 5,
    );
    expect(created.isOk, isTrue);
    final queue = (await repo.watchQueueOfProvider(_owner.id).first)!;
    for (var number = 1; number <= 100; number++) {
      final joined = await repo.join(
        customer: AppUser(
          id: 'customer-$number',
          name:
              'Customer ${number.toString().padLeft(3, '0')}'
              '${longNames ? ' with a long name that wraps across several lines' : ''}',
          email: 'customer$number@example.com',
          role: UserRole.customer,
        ),
        queueId: queue.id,
      );
      expect(joined.isOk, isTrue);
    }
    return repo;
  }

  testWidgets(
    '100 customers render lazily with Call Next visible above the list',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final repo = (await tester.runAsync(() => longQueue()))!;
        await showScreen(
          tester,
          repository: repo,
          screen: const QueueManagementScreen(),
        );
        final callNext = filled('Call Next');
        expect(callNext.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(callNext).onPressed, isNotNull);
        expect(
          tester.getBottomLeft(callNext).dy,
          lessThan(tester.getTopLeft(find.text('Waiting customers (100)')).dy),
        );
        expect(find.text('Customer 001'), findsOneWidget);
        expect(find.text('Customer 100'), findsNothing);
        final customerSemantics = tester
            .getSemantics(
              find
                  .descendant(
                    of: find.byType(ProviderWaitingSliver),
                    matching: find.byType(MergeSemantics),
                  )
                  .first,
            )
            .getSemanticsData()
            .label;
        expect(customerSemantics, contains('Ticket 1'));
        expect(customerSemantics, contains('Customer 001'));
        expect(customerSemantics, contains('Waiting. Joined at'));
        final visibleCount = find
            .byType(ProviderWaitingCustomer)
            .evaluate()
            .length;
        expect(visibleCount, greaterThan(0));
        expect(visibleCount, lessThan(20));
        await tester.scrollUntilVisible(
          find.text('Customer 100'),
          300,
          maxScrolls: 100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final last = find.byWidgetPredicate(
          (widget) =>
              widget is ProviderWaitingCustomer &&
              widget.entry.ticketNumber == 100,
        );
        expect(
          find.descendant(of: last, matching: find.text('#100')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: last, matching: find.text('Customer 100')),
          findsOneWidget,
        );
        expect(find.text('Customer 001'), findsNothing);
        expect(
          find.byType(ProviderWaitingCustomer).evaluate().length,
          lessThan(20),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    '100 shuffled entries keep join order and fixed tickets after a live leave',
    (tester) async {
      final repo = (await tester.runAsync(() => longQueue()))!;
      final entries = (await tester.runAsync(() async {
        final queue = (await repo.watchQueueOfProvider(_owner.id).first)!;
        return repo.watchEntries(queue.id).first;
      }))!;
      final stream = StreamController<List<QueueEntry>>.broadcast();
      addTearDown(() {
        unawaited(stream.close());
      });
      repo.entriesStream = stream;
      await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
        settle: false,
      );
      await tester.pump();
      stream.add(entries.reversed.toList());
      await tester.pumpAndSettle();
      final firstRows = tester
          .widgetList<ProviderWaitingCustomer>(
            find.byType(ProviderWaitingCustomer),
          )
          .toList();
      expect(firstRows.length, greaterThan(1));
      for (var index = 0; index < firstRows.length; index++) {
        expect(firstRows[index].entry.id, entries[index].id);
        expect(firstRows[index].entry.ticketNumber, index + 1);
        expect(firstRows[index].entry.status, MembershipStatus.waiting);
      }
      await tester.scrollUntilVisible(
        find.text('Customer 100'),
        300,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      stream.add([
        for (final entry in entries.reversed)
          entry.id == entries.first.id
              ? entry.copyWith(status: MembershipStatus.left)
              : entry,
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Customer 100'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Customer 002'),
        -300,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer 001'), findsNothing);
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is ProviderWaitingCustomer &&
            widget.entry.id == entries[1].id,
      );
      expect(
        find.descendant(of: row, matching: find.text('#02')),
        findsOneWidget,
      );
      final joined = entries[1].joinedAt.toLocal();
      final time =
          '${joined.hour.toString().padLeft(2, '0')}:${joined.minute.toString().padLeft(2, '0')}';
      expect(
        find.descendant(of: row, matching: find.text('Waiting · Joined $time')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A long queue preserves busy guards and the called-customer actions',
    (tester) async {
      final repo = (await tester.runAsync(() => longQueue()))!;
      final gate = Completer<OperationResult>();
      repo.callGate = gate;
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      final submit = tester
          .widget<FilledButton>(filled('Call Next'))
          .onPressed!;
      await tester.tap(filled('Call Next'));
      submit();
      await tester.pump();
      await reveal(tester, filled('Mark as Served'));
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(outlined('Skip')).onPressed, isNull);
      await reveal(tester, filled('Calling…'));
      expect(tester.widget<FilledButton>(filled('Calling…')).onPressed, isNull);
      expect(repo.callRequests, 1);
      gate.complete(OperationResult.ok);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        filled('Mark as Served'),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(state.calledEntry!.ticketNumber, 1);
      expect(state.waitingEntries.length, 99);
      expect(find.text('#01 · Customer 001'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filled('Call Next')).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<OutlinedButton>(outlined('Skip')).onPressed,
        isNotNull,
      );
      await tester.scrollUntilVisible(
        find.text('Customer 002'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('#02'), findsOneWidget);
      expect(repo.callRequests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [280.0, 320.0]) {
    testWidgets('100 long customer names fit ${width.toInt()}px at 200% text', (
      tester,
    ) async {
      final repo = (await tester.runAsync(() => longQueue(longNames: true)))!;
      await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
        size: Size(width, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        filled('Call Next'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(filled('Call Next').hitTestable(), findsOneWidget);
      expect(find.textContaining('Customer 100'), findsNothing);
      await tester.scrollUntilVisible(
        find.text(
          'Customer 100 with a long name that wraps across several lines',
        ),
        300,
        maxScrolls: 400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('#100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final bottomNavigation in [false, true]) {
    testWidgets('Android Back returns management to Dashboard via '
        '${bottomNavigation ? 'bottom navigation' : 'dashboard button'}', (
      tester,
    ) async {
      await showScreen(tester, repository: QueueRepository());
      if (bottomNavigation) {
        await tester.tap(find.byType(NavigationDestination).last);
      } else {
        await tap(tester, filled('Manage Queue'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(QueueManagementScreen), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(QueueManagementScreen)))
            ?.settings
            .name,
        '/manage-queue',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDashboardScreen), findsOneWidget);
      expect(find.byType(QueueManagementScreen), findsNothing);
    });
  }

  for (final action in ['create', 'call', 'serve', 'skip']) {
    testWidgets(
      'Permanently pending $action allows Back and Profile without another write',
      (tester) async {
        final gate = Completer<OperationResult>();
        final create = action == 'create';
        final repo = _ControlledRepository(seedSampleData: !create);
        if (create) {
          repo.createGate = gate;
        } else if (action == 'call') {
          await repo.finishCalled(
            provider: _owner,
            queueId: 'campus-barber',
            outcome: MembershipStatus.served,
          );
          repo.finishRequests = 0;
          repo.callGate = gate;
        } else {
          repo.finishGate = gate;
        }
        final state = await showScreen(
          tester,
          repository: repo,
          screen: create
              ? const CreateQueueScreen()
              : const QueueManagementScreen(),
        );
        if (create) await fillForm(tester);
        final button = switch (action) {
          'create' => filled('Create Queue'),
          'call' => filled('Call Next'),
          'serve' => filled('Mark as Served'),
          _ => outlined('Skip'),
        };
        final submit = tester.widget<ButtonStyleButton>(button).onPressed!;
        await tap(tester, button);
        // A second event using the original callback cannot bypass the guard,
        // even before the disabled button has replaced the original widget.
        submit();
        await tester.pump(const Duration(minutes: 5));
        expect(state.isBusy, isTrue);
        expect(find.text('Queue request pending'), findsOneWidget);
        expect(find.textContaining('may still complete'), findsOneWidget);
        expect(find.text('Creation failed'), findsNothing);
        // Refresh is a read, even when the write has not returned.
        await tap(tester, outlined('Refresh queue details'));
        await finishNavigation(tester);
        await tester.binding.handlePopRoute();
        await finishNavigation(tester);
        expect(find.byType(ProviderDashboardScreen), findsOneWidget);
        expect(find.text('Queue request pending'), findsOneWidget);
        if (create) {
          await reveal(tester, filled('Create Queue'));
          expect(
            tester.widget<FilledButton>(filled('Create Queue')).onPressed,
            isNull,
          );
        } else {
          await tap(tester, filled('Manage Queue'));
          await finishNavigation(tester);
          await reveal(tester, filled('Mark as Served'));
          expect(
            tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
            isNull,
          );
          expect(
            tester.widget<OutlinedButton>(outlined('Skip')).onPressed,
            isNull,
          );
          await reveal(tester, filled('Call Next'));
          expect(
            tester.widget<FilledButton>(filled('Call Next')).onPressed,
            isNull,
          );
          await tap(tester, filled('Call Next'));
          await tester.tap(find.byType(NavigationDestination).first);
          await finishNavigation(tester);
          expect(find.byType(ProviderDashboardScreen), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Profile'));
        await finishNavigation(tester);
        expect(find.text('Profile destination'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await finishNavigation(tester);
        expect(find.byType(ProviderDashboardScreen), findsOneWidget);
        expect(repo.createRequests, create ? 1 : 0);
        expect(repo.callRequests, action == 'call' ? 1 : 0);
        expect(repo.finishRequests, !create && action != 'call' ? 1 : 0);
        expect(gate.isCompleted, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final create in [false, true]) {
    for (final succeeds in [false, true]) {
      testWidgets(
        'Delayed ${create ? 'creation' : 'update'} '
        '${succeeds ? 'success' : 'failure'} after leaving stays on Dashboard',
        (tester) async {
          final gate = Completer<OperationResult>();
          final repo = _ControlledRepository(seedSampleData: !create);
          if (create) {
            repo.createGate = gate;
          } else {
            repo.finishGate = gate;
          }
          final state = await showScreen(
            tester,
            repository: repo,
            screen: create
                ? const CreateQueueScreen()
                : const QueueManagementScreen(),
          );
          if (create) await fillForm(tester);
          await tap(tester, filled(create ? 'Create Queue' : 'Mark as Served'));
          await tester.tap(find.byTooltip('Back to Dashboard'));
          await finishNavigation(tester);
          expect(
            find.byType(create ? CreateQueueScreen : QueueManagementScreen),
            findsNothing,
          );
          gate.complete(
            succeeds
                ? OperationResult.ok
                : OperationResult.failure(OperationError.failed),
          );
          await tester.pumpAndSettle();
          expect(state.isBusy, isFalse);
          expect(find.byType(ProviderDashboardScreen), findsOneWidget);
          expect(find.text('Queue request pending'), findsNothing);
          expect(
            create ? state.queue != null : state.calledEntry == null,
            succeeds,
          );
          expect(repo.createRequests, create ? 1 : 0);
          expect(repo.finishRequests, create ? 0 : 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Dashboard loading shows no stale data or enabled management', (
    tester,
  ) async {
    await showScreen(
      tester,
      repository: _ControlledRepository()..holdLoading = true,
      settle: false,
    );
    await tester.pump();
    expect(find.text('Loading your queue...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Campus Barber'), findsNothing);
    expect(
      tester
          .widget<NavigationDestination>(
            find.byType(NavigationDestination).last,
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('Dashboard empty state opens Create Queue', (tester) async {
    await showScreen(
      tester,
      repository: QueueRepository(seedSampleData: false),
    );
    expect(find.text('No queue yet'), findsOneWidget);
    await tap(tester, filled('Create Queue'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateQueueScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-name')), findsOneWidget);
  });

  testWidgets(
    'Dashboard displays actual queue, counts, called customer and profile',
    (tester) async {
      await showScreen(tester, repository: QueueRepository());
      expect(find.text('Campus Barber'), findsOneWidget);
      expect(find.text('3 customers waiting'), findsOneWidget);
      expect(
        find.text('4 in queue, including 1 called customer'),
        findsOneWidget,
      );
      expect(find.text('Avg. 5 min/customer'), findsOneWidget);
      expect(find.text('#09 · Ahmed Ali'), findsOneWidget);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile destination'), findsOneWidget);
    },
  );

  for (final screen in <Widget>[
    const ProviderDashboardScreen(),
    const CreateQueueScreen(),
    const QueueManagementScreen(),
  ]) {
    testWidgets('${screen.runtimeType} retries queue loading', (tester) async {
      final repo = _ControlledRepository()..failLoading = true;
      await showScreen(tester, repository: repo, screen: screen);
      expect(find.text('Couldn’t load your queue'), findsOneWidget);
      expect(find.text('Campus Barber'), findsNothing);
      repo.failLoading = false;
      await tap(tester, filled('Retry'));
      await tester.pumpAndSettle();
      expect(repo.loadRequests, 2);
      expect(find.text('Campus Barber'), findsOneWidget);
      expect(find.text('Couldn’t load your queue'), findsNothing);
    });
  }

  testWidgets('Management retries an entries stream error', (tester) async {
    final repo = _ControlledRepository()..failEntries = true;
    await showScreen(
      tester,
      repository: repo,
      screen: const QueueManagementScreen(),
    );
    expect(find.text('Couldn’t load your queue'), findsOneWidget);
    repo.failEntries = false;
    await tap(tester, filled('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting customers (3)'), findsOneWidget);
  });

  testWidgets(
    'Create requires name, description and duration without a write',
    (tester) async {
      final repo = _ControlledRepository(seedSampleData: false);
      await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      await tester.enterText(find.byKey(const ValueKey('queue-name')), '   ');
      await tester.enterText(find.byKey(const ValueKey('queue-minutes')), '');
      await tap(tester, filled('Create Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Queue name is required.'), findsOneWidget);
      expect(find.text('Description is required.'), findsOneWidget);
      expect(find.text('Service duration is required.'), findsOneWidget);
      expect(repo.createRequests, 0);
    },
  );

  testWidgets(
    'Create rejects zero, negative, decimal, text and oversized duration',
    (tester) async {
      final repo = _ControlledRepository(seedSampleData: false);
      await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      await fillForm(tester);
      for (final value in [
        '0',
        '-1',
        '1.5',
        'abc',
        '999999999999999999999999999999',
      ]) {
        await tester.enterText(
          find.byKey(const ValueKey('queue-minutes')),
          value,
        );
        await tap(tester, filled('Create Queue'));
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number greater than 0.'),
          findsOneWidget,
        );
      }
      expect(repo.createRequests, 0);
    },
  );

  testWidgets(
    'Create disables duplicate submit and fields, allows leaving, and retry saves',
    (tester) async {
      final gate = Completer<OperationResult>();
      final repo = _ControlledRepository(seedSampleData: false)
        ..createGate = gate;
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      await fillForm(tester);
      await tap(tester, filled('Create Queue'));
      expect(state.isBusy, isTrue);
      expect(repo.createRequests, 1);
      expect(
        tester.widget<FilledButton>(filled('Creating queue…')).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(outlined('Back to Dashboard')).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('queue-name')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<NavigationDestination>(
              find.byType(NavigationDestination).first,
            )
            .enabled,
        isTrue,
      );
      gate.complete(OperationResult.failure(OperationError.failed));
      await tester.pumpAndSettle();
      expect(find.text('Creation failed'), findsOneWidget);
      expect(find.text(' Campus Barber '), findsOneWidget);
      repo.createGate = null;
      await tap(tester, filled('Retry creation'));
      await tester.pumpAndSettle();
      expect(repo.createRequests, 2);
      expect(find.text('Queue created'), findsOneWidget);
      expect(state.queue!.name, 'Campus Barber');
      expect(state.queue!.description, 'Barber service');
      expect(state.queue!.averageServiceMinutes, 5);
      expect(find.byType(TextFormField), findsNothing);
      await tap(tester, filled('Manage Queue'));
      await tester.pumpAndSettle();
      expect(find.byType(QueueManagementScreen), findsOneWidget);
      expect(find.text('Campus Barber'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDashboardScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Opening create with an existing queue prevents another submission',
    (tester) async {
      final repo = _ControlledRepository();
      await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
      );
      expect(find.text('You already have a queue'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(filled('Create Queue'), findsNothing);
      expect(repo.createRequests, 0);
      await tap(tester, outlined('Back to Dashboard'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDashboardScreen), findsOneWidget);
    },
  );

  testWidgets('Create handles a repository duplicate-queue rejection', (
    tester,
  ) async {
    final gate = Completer<OperationResult>();
    final repo = _ControlledRepository(seedSampleData: false)
      ..createGate = gate;
    await showScreen(
      tester,
      repository: repo,
      screen: const CreateQueueScreen(),
    );
    await fillForm(tester);
    await tap(tester, filled('Create Queue'));
    gate.complete(OperationResult.failure(OperationError.hasQueue));
    await tester.pumpAndSettle();
    expect(
      find.text('Each provider can create only one queue.'),
      findsOneWidget,
    );
    expect(find.text('Queue created'), findsNothing);
  });

  testWidgets(
    'Empty management disables all actions and reacts to a customer joining',
    (tester) async {
      final repo = QueueRepository(seedSampleData: false);
      await repo.createQueue(
        provider: _owner,
        name: 'Clinic',
        description: 'Appointments',
        averageServiceMinutes: 5,
      );
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.byType(ProviderWaitingSliver), findsNothing);
      expect(find.byType(ProviderWaitingCustomer), findsNothing);
      expect(
        tester.widget<FilledButton>(filled('Call Next')).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(outlined('Skip')).onPressed, isNull);
      await repo.join(
        customer: const AppUser(
          id: 'a',
          name: 'First Customer',
          email: 'a@example.com',
          role: UserRole.customer,
        ),
        queueId: state.queue!.id,
      );
      await tester.pumpAndSettle();
      expect(find.text('First Customer'), findsOneWidget);
      expect(find.byType(ProviderWaitingSliver), findsOneWidget);
      expect(find.byType(ProviderWaitingCustomer), findsOneWidget);
      expect(find.text('Waiting customers (1)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filled('Call Next')).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Waiting list follows joining order and displays actual joined times',
    (tester) async {
      final repo = QueueRepository();
      await repo.finishCalled(
        provider: _owner,
        queueId: 'campus-barber',
        outcome: MembershipStatus.served,
      );
      await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(outlined('Skip')).onPressed, isNull);
      await reveal(tester, find.text('Noor Abdullah'));
      expect(
        tester.getTopLeft(find.text('Sara Hassan')).dy,
        lessThan(tester.getTopLeft(find.text('Omar Khalid')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Omar Khalid')).dy,
        lessThan(tester.getTopLeft(find.text('Noor Abdullah')).dy),
      );
      expect(find.text('Waiting · Joined 10:02'), findsOneWidget);
      expect(find.text('#10'), findsOneWidget);
    },
  );

  testWidgets('Called blocks Call Next; Served and Skip never auto-call', (
    tester,
  ) async {
    final repo = QueueRepository();
    final state = await showScreen(
      tester,
      repository: repo,
      screen: const QueueManagementScreen(),
    );
    await tester.scrollUntilVisible(
      filled('Call Next'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(filled('Call Next')).onPressed, isNull);
    await tap(tester, filled('Mark as Served'));
    await tester.pumpAndSettle();
    expect(find.text('#09 Ahmed Ali — Served'), findsOneWidget);
    expect(state.calledEntry, isNull);
    expect(state.waitingEntries.length, 3);
    expect(
      tester.widget<FilledButton>(filled('Call Next')).onPressed,
      isNotNull,
    );
    await tap(tester, filled('Call Next'));
    await tester.pumpAndSettle();
    expect(state.calledEntry!.customerName, 'Sara Hassan');
    expect(state.waitingEntries.length, 2);
    expect(tester.widget<FilledButton>(filled('Call Next')).onPressed, isNull);
    await tap(tester, outlined('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('#10 Sara Hassan — Skipped'), findsOneWidget);
    expect(state.calledEntry, isNull);
    expect(state.waitingEntries.map((entry) => entry.ticketNumber), [11, 12]);
    expect(
      tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
      isNull,
    );
  });

  for (final skip in [false, true]) {
    testWidgets(
      'Pending ${skip ? 'Skip' : 'Served'} disables actions and failure retries',
      (tester) async {
        final gate = Completer<OperationResult>();
        final repo = _ControlledRepository()..finishGate = gate;
        final state = await showScreen(
          tester,
          repository: repo,
          screen: const QueueManagementScreen(),
        );
        await tap(tester, skip ? outlined('Skip') : filled('Mark as Served'));
        expect(repo.finishRequests, 1);
        expect(
          tester
              .widget<FilledButton>(filled(skip ? 'Mark as Served' : 'Saving…'))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(outlined(skip ? 'Skipping…' : 'Skip'))
              .onPressed,
          isNull,
        );
        await reveal(tester, filled('Call Next'));
        expect(
          tester.widget<FilledButton>(filled('Call Next')).onPressed,
          isNull,
        );
        gate.complete(OperationResult.failure(OperationError.failed));
        await tester.pumpAndSettle();
        expect(state.calledEntry!.ticketNumber, 9);
        expect(
          find.textContaining('Ahmed Ali is still called.'),
          findsOneWidget,
        );
        repo.finishGate = null;
        await tap(
          tester,
          skip ? outlined('Retry skip') : filled('Retry update'),
        );
        await tester.pumpAndSettle();
        expect(repo.finishRequests, 2);
        expect(state.calledEntry, isNull);
        expect(state.waitingEntries.length, 3);
      },
    );
  }

  testWidgets('Pending Call Next disables actions and failed call retries', (
    tester,
  ) async {
    final gate = Completer<OperationResult>();
    final repo = _ControlledRepository()..callGate = gate;
    await repo.finishCalled(
      provider: _owner,
      queueId: 'campus-barber',
      outcome: MembershipStatus.served,
    );
    final state = await showScreen(
      tester,
      repository: repo,
      screen: const QueueManagementScreen(),
    );
    await tap(tester, filled('Call Next'));
    expect(repo.callRequests, 1);
    await reveal(tester, filled('Calling…'));
    expect(tester.widget<FilledButton>(filled('Calling…')).onPressed, isNull);
    gate.complete(OperationResult.failure(OperationError.failed));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t call #10.'), findsOneWidget);
    repo.callGate = null;
    await tap(tester, filled('Retry Call Next'));
    await tester.pumpAndSettle();
    expect(repo.callRequests, 2);
    expect(state.calledEntry!.ticketNumber, 10);
  });

  for (final call in [false, true]) {
    testWidgets(
      '${call ? 'Call' : 'Finish'} confirmation survives navigation and read refresh',
      (tester) async {
        final repo = _ControlledRepository();
        if (call) {
          await repo.finishCalled(
            provider: _owner,
            queueId: 'campus-barber',
            outcome: MembershipStatus.served,
          );
          repo.finishRequests = 0;
        }
        final state = await showScreen(
          tester,
          repository: repo,
          screen: const QueueManagementScreen(),
        );
        final entries = state.activeEntries;
        final target = call ? state.waitingEntries.first : state.calledEntry!;
        final stream = StreamController<List<QueueEntry>>.broadcast();
        repo.entriesStream = stream;
        addTearDown(() {
          unawaited(stream.close());
        });
        state.retry();
        await tester.pump();
        stream.add(entries);
        await tester.pumpAndSettle();
        await tap(tester, filled(call ? 'Call Next' : 'Mark as Served'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(state.isBusy, isFalse);
        await tester.tap(find.byTooltip('Back to Dashboard'));
        await finishNavigation(tester);
        expect(find.byType(QueueManagementScreen), findsNothing);
        await tap(tester, filled('Manage Queue'));
        await finishNavigation(tester);
        expect(find.text('Waiting for queue updates'), findsOneWidget);
        // Refresh cannot mistake the temporarily cleared entries for confirmation.
        await tap(tester, outlined('Refresh queue details'));
        expect(state.status, LoadStatus.loading);
        await tester.pump();
        stream.add(entries);
        await finishNavigation(tester);
        expect(state.status, LoadStatus.ready);
        expect(find.text('Waiting for queue updates'), findsOneWidget);
        await reveal(tester, filled('Mark as Served'));
        expect(
          tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
          isNull,
        );
        expect(
          tester.widget<OutlinedButton>(outlined('Skip')).onPressed,
          isNull,
        );
        await reveal(tester, filled('Call Next'));
        expect(
          tester.widget<FilledButton>(filled('Call Next')).onPressed,
          isNull,
        );
        stream.add(
          entries
              .map(
                (entry) => entry.id == target.id
                    ? entry.copyWith(
                        status: call
                            ? MembershipStatus.called
                            : MembershipStatus.served,
                      )
                    : entry,
              )
              .toList(),
        );
        await tester.pumpAndSettle();
        await reveal(tester, filled('Call Next'));
        expect(
          tester.widget<FilledButton>(filled('Call Next')).onPressed,
          call ? isNull : isNotNull,
        );
        expect(find.text('Waiting for queue updates'), findsNothing);
        expect(repo.finishRequests, call ? 0 : 1);
        expect(repo.callRequests, call ? 1 : 0);
      },
    );
  }

  testWidgets(
    'Created queue cannot be resubmitted while its snapshot is delayed',
    (tester) async {
      final stream = StreamController<ServiceQueue?>.broadcast();
      final repo = _ControlledRepository(seedSampleData: false)
        ..queueStream = stream;
      addTearDown(() {
        unawaited(stream.close());
      });
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const CreateQueueScreen(),
        settle: false,
      );
      await tester.pump();
      stream.add(null);
      await tester.pumpAndSettle();
      await fillForm(tester);
      await tap(tester, filled('Create Queue'));
      await finishNavigation(tester);
      expect(state.isBusy, isFalse);
      expect(find.text('Waiting for queue updates'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to Dashboard'));
      await finishNavigation(tester);
      await reveal(tester, filled('Create Queue'));
      expect(
        tester.widget<FilledButton>(filled('Create Queue')).onPressed,
        isNull,
      );
      // Even a direct visit to the existing route cannot bypass the write guard.
      Navigator.of(tester.element(find.byType(ProviderDashboardScreen)))
          .pushNamed('/create-queue');
      await finishNavigation(tester);
      await reveal(tester, filled('Creating queue…'));
      expect(
        tester.widget<FilledButton>(filled('Creating queue…')).onPressed,
        isNull,
      );
      expect(repo.createRequests, 1);
      stream.add(
        const ServiceQueue(
          id: 'q1',
          providerId: 'provider-1',
          name: 'Campus Barber',
          description: 'Barber service',
          averageServiceMinutes: 5,
          isOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for queue updates'), findsNothing);
      expect(find.text('You already have a queue'), findsOneWidget);
      expect(repo.createRequests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Provider actions reach the customer membership stream', (
    tester,
  ) async {
    final repo = QueueRepository();
    final customer = MembershipProvider(repo)
      ..bindUser(
        const AppUser(
          id: 'customer-1',
          name: 'Noor Abdullah',
          email: 'customer@example.com',
          role: UserRole.customer,
        ),
      );
    addTearDown(customer.dispose);
    await showScreen(
      tester,
      repository: repo,
      screen: const QueueManagementScreen(),
    );
    expect(customer.customersAhead, 3);
    await tap(tester, filled('Mark as Served'));
    await tester.pumpAndSettle();
    expect(customer.customersAhead, 2);
    expect(customer.estimatedWaitMinutes, 10);
    expect(customer.currentEntry!.ticketNumber, 12);
  });

  for (final create in [false, true]) {
    testWidgets('Disposing during ${create ? 'creation' : 'update'} is safe', (
      tester,
    ) async {
      final gate = Completer<OperationResult>();
      final repo = _ControlledRepository(seedSampleData: !create);
      if (create) {
        repo.createGate = gate;
      } else {
        repo.finishGate = gate;
      }
      await showScreen(
        tester,
        repository: repo,
        screen: create
            ? const CreateQueueScreen()
            : const QueueManagementScreen(),
      );
      if (create) await fillForm(tester);
      await tap(tester, filled(create ? 'Create Queue' : 'Mark as Served'));
      await tester.pumpWidget(const SizedBox());
      gate.complete(OperationResult.failure(OperationError.failed));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in <Widget>[
    const ProviderDashboardScreen(),
    const CreateQueueScreen(),
    const QueueManagementScreen(),
  ]) {
    testWidgets('${screen.runtimeType} fits 280px with large text', (
      tester,
    ) async {
      await showScreen(
        tester,
        repository: QueueRepository(
          seedSampleData: screen is! CreateQueueScreen,
        ),
        screen: screen,
        size: const Size(280, 640),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      if (screen is CreateQueueScreen) {
        await tester.enterText(
          find.byKey(const ValueKey('queue-minutes')),
          '0',
        );
        await tap(tester, filled('Create Queue'));
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number greater than 0.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Create scrolls above the keyboard on a narrow screen', (
    tester,
  ) async {
    final repo = QueueRepository(seedSampleData: false);
    await showScreen(
      tester,
      repository: repo,
      screen: const CreateQueueScreen(),
      size: const Size(320, 640),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await fillForm(tester);
    await tester.pumpAndSettle();
    await tap(tester, filled('Create Queue'));
    await tester.pumpAndSettle();
    expect(find.text('Queue created'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Existing application routes sign in a provider and open management',
    (tester) async {
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
      await tester.enterText(
        find.byType(TextFormField).first,
        'provider@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'demopass');
      await tap(tester, filled('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Provider Dashboard'), findsOneWidget);
      await tap(tester, filled('Manage Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Queue Management'), findsOneWidget);
      expect(find.text('#09 · Ahmed Ali'), findsOneWidget);
    },
  );

  for (final logout in [false, true]) {
    testWidgets(
      'Delayed write preserves ${logout ? 'logout' : 'Profile'} navigation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gate = Completer<OperationResult>();
        final repo = _ControlledRepository()..finishGate = gate;
        await tester.pumpWidget(
          AppProviders(
            authRepository: AuthRepository(),
            queueRepository: repo,
            child: const QueueLessApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'provider@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'demopass');
        await tap(tester, filled('Sign In'));
        await tester.pumpAndSettle();
        await tap(tester, filled('Manage Queue'));
        await tester.pumpAndSettle();
        await tap(tester, filled('Mark as Served'));
        await tester.tap(find.byTooltip('Profile'));
        await finishNavigation(tester);
        expect(find.byType(ProfileScreen), findsOneWidget);
        if (logout) {
          await tap(tester, find.text('Logout'));
          await finishNavigation(tester);
          await tap(tester, filled('Log Out'));
          await finishNavigation(tester);
          expect(find.byType(LoginScreen), findsOneWidget);
        }
        gate.complete(OperationResult.ok);
        await tester.pumpAndSettle();
        expect(
          find.byType(logout ? LoginScreen : ProfileScreen),
          findsOneWidget,
        );
        expect(repo.finishRequests, 1);
        expect(tester.takeException(), isNull);
        if (!logout) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(QueueManagementScreen), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(ProviderDashboardScreen), findsOneWidget);
        }
      },
    );
  }
}
