import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/main.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/app_providers.dart';
import 'package:swe463_group7_project/providers/membership_provider.dart';
import 'package:swe463_group7_project/providers/provider_queue_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/screens/provider_screens.dart';

class _ControlledRepository extends QueueRepository {
  _ControlledRepository({super.seedSampleData});

  bool failLoading = false;
  bool holdLoading = false;
  bool failEntries = false;
  int loadRequests = 0;
  int createRequests = 0;
  int callRequests = 0;
  int finishRequests = 0;
  Completer<OperationResult>? createGate;
  Completer<OperationResult>? callGate;
  Completer<OperationResult>? finishGate;
  StreamController<List<QueueEntry>>? entriesStream;

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) {
    loadRequests++;
    if (holdLoading) return const Stream.empty();
    if (failLoading) return Stream.error(StateError('offline'));
    return super.watchQueueOfProvider(providerId);
  }

  @override
  Stream<List<QueueEntry>> watchEntries(String queueId) {
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
    'Create disables duplicate submit, fields, cancel and navigation; retry saves',
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
        tester.widget<OutlinedButton>(outlined('Cancel')).onPressed,
        isNull,
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
        isFalse,
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
        tester.getTopLeft(find.text('Sara Hassan')).dy,
        lessThan(tester.getTopLeft(find.text('Omar Khalid')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Omar Khalid')).dy,
        lessThan(tester.getTopLeft(find.text('Noor Abdullah')).dy),
      );
      expect(find.text('Waiting · Joined 10:02'), findsOneWidget);
      expect(find.text('#10'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(outlined('Skip')).onPressed, isNull);
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

  testWidgets(
    'Write success stays disabled until the entries snapshot changes',
    (tester) async {
      final repo = _ControlledRepository();
      final state = await showScreen(
        tester,
        repository: repo,
        screen: const QueueManagementScreen(),
      );
      final entries = state.activeEntries;
      final stream = StreamController<List<QueueEntry>>();
      repo.entriesStream = stream;
      addTearDown(() {
        unawaited(stream.close());
      });
      state.retry();
      await tester.pump();
      stream.add(entries);
      await tester.pumpAndSettle();
      await tap(tester, filled('Mark as Served'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.isBusy, isFalse);
      expect(
        tester.widget<FilledButton>(filled('Mark as Served')).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(outlined('Skip')).onPressed, isNull);
      expect(
        tester.widget<FilledButton>(filled('Call Next')).onPressed,
        isNull,
      );
      stream.add(
        entries
            .map(
              (entry) => entry.id == 'e9'
                  ? entry.copyWith(status: MembershipStatus.served)
                  : entry,
            )
            .toList(),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(filled('Call Next')).onPressed,
        isNotNull,
      );
      expect(repo.finishRequests, 1);
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
      await tap(tester, filled('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Provider Dashboard'), findsOneWidget);
      await tap(tester, filled('Manage Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Queue Management'), findsOneWidget);
      expect(find.text('#09 · Ahmed Ali'), findsOneWidget);
    },
  );
}
