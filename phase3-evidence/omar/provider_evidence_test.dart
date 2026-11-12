// Reproducible UI evidence only. This harness never initializes Firebase.
// Run from the repository root:
// flutter test phase3-evidence/omar/provider_evidence_test.dart --reporter expanded
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const _evidenceRoot = 'phase3-evidence/omar';
final _capture = GlobalKey();

class _EvidenceRepository extends QueueRepository {
  _EvidenceRepository({super.seedSampleData = false});
  bool holdLoading = false;
  bool failLoading = false;
  Completer<OperationResult>? createGate;
  Completer<OperationResult>? finishGate;

  @override
  Stream<ServiceQueue?> watchQueueOfProvider(String providerId) {
    if (holdLoading) return const Stream.empty();
    if (failLoading) {
      return Stream.error(StateError('Local simulated network failure'));
    }
    return super.watchQueueOfProvider(providerId);
  }

  @override
  Future<OperationResult> createQueue({
    required AppUser provider,
    required String name,
    required String description,
    required int averageServiceMinutes,
  }) async {
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
  Future<OperationResult> finishCalled({
    required AppUser provider,
    required String queueId,
    required MembershipStatus outcome,
  }) async {
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

Future<void> _loadFonts() async {
  final configUri = File('.dart_tool/package_config.json').absolute.uri;
  final config = jsonDecode(
    File.fromUri(configUri).readAsStringSync(),
  ) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((package) => package['name'] == 'flutter');
  final sdk = Directory.fromUri(configUri.resolve(flutter['rootUri'] as String))
      .parent
      .parent;
  final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    roboto.addFont(
      Future.value(
        ByteData.sublistView(File('$fonts/$name').readAsBytesSync()),
      ),
    );
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(
            File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync(),
          ),
        ),
      ))
      .load();
}

Finder _filled(String text) => find.widgetWithText(FilledButton, text);
Finder _outlined(String text) => find.widgetWithText(OutlinedButton, text);

Future<void> _tap(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(button);
  await tester.pump();
}

Future<ProviderQueueProvider> _start(
  WidgetTester tester,
  QueueRepository repository, {
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 884));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppProviders(
      authRepository: AuthRepository(),
      queueRepository: repository,
      child: RepaintBoundary(
        key: _capture,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              const SizedBox(
                height: 40,
                width: double.infinity,
                child: ColoredBox(
                  color: Color(0xFFFFE6B6),
                  child: Center(
                    child: Text(
                      'LOCAL MOCK UI - WIDGET TEST - NO FIREBASE',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF654000),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              const Expanded(child: QueueLessApp()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).first,
    'provider@example.com',
  );
  await _tap(tester, _filled('Sign In'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return tester
      .element(find.byType(ProviderDashboardScreen))
      .read<ProviderQueueProvider>();
}

Future<void> _shot(WidgetTester tester, String name) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final scrollable = find.byType(Scrollable).first;
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File('$_evidenceRoot/screenshots/mock-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

Future<void> _fill(WidgetTester tester, {String minutes = '5'}) async {
  await tester.enterText(
    find.byKey(const ValueKey('queue-name')),
    'Campus Barber',
  );
  await tester.enterText(
    find.byKey(const ValueKey('queue-description')),
    'Barber service',
  );
  await tester.enterText(find.byKey(const ValueKey('queue-minutes')), minutes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Directory('$_evidenceRoot/screenshots').createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets(
    'MOCK evidence: actual provider routes, creation, separate customers, called, served and skipped',
    (tester) async {
      final repository = _EvidenceRepository();
      final provider = await _start(tester, repository);
      expect(find.text('No queue yet'), findsOneWidget);
      await _shot(tester, 'dashboard-empty');
      await _tap(tester, _filled('Create Queue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('queue-minutes')), '');
      await _tap(tester, _filled('Create Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Queue name is required.'), findsOneWidget);
      expect(find.text('Description is required.'), findsOneWidget);
      expect(find.text('Service duration is required.'), findsOneWidget);
      await _shot(tester, 'create-required-fields');
      await _fill(tester, minutes: '0');
      await _tap(tester, _filled('Create Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number greater than 0.'), findsOneWidget);
      await _shot(tester, 'create-invalid-duration');
      await _fill(tester);
      await tester.pumpAndSettle();
      await _shot(tester, 'create-queue-form');
      final failureGate = Completer<OperationResult>();
      repository.createGate = failureGate;
      await _tap(tester, _filled('Create Queue'));
      expect(provider.isBusy, isTrue);
      expect(
        tester.widget<FilledButton>(_filled('Creating queue…')).onPressed,
        isNull,
      );
      await _shot(tester, 'create-queue-creating');
      failureGate.complete(OperationResult.failure(OperationError.failed));
      await tester.pumpAndSettle();
      expect(find.text('Creation failed'), findsOneWidget);
      await _shot(tester, 'create-queue-error');
      repository.createGate = null;
      await _tap(tester, _filled('Retry creation'));
      await tester.pumpAndSettle();
      expect(find.text('Queue created'), findsOneWidget);
      expect(provider.queue!.name, 'Campus Barber');
      expect(provider.queue!.averageServiceMinutes, 5);
      await _shot(tester, 'create-queue-success');
      await _tap(tester, _outlined('Back to Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('0 customers waiting'), findsOneWidget);
      await _shot(tester, 'dashboard-active');
      await _tap(tester, _filled('Manage Queue'));
      await tester.pumpAndSettle();
      expect(find.text('All caught up'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_filled('Call Next')).onPressed,
        isNull,
      );
      await _shot(tester, 'management-empty');

      // Two local customer accounts have independent membership observers.
      // Their accounts and all queue records exist only in memory.
      final customerAccounts = AuthRepository(seedDemoAccounts: false);
      final saraAccount = await customerAccounts.register(
        name: 'Sara Hassan',
        email: 'sara@phase3.example.invalid',
        password: 'LocalOnly463!',
        role: UserRole.customer,
      );
      final second = await customerAccounts.register(
        name: 'Omar Khalid',
        email: 'omar@phase3.example.invalid',
        password: 'LocalOnly463!',
        role: UserRole.customer,
      );
      final sara = MembershipProvider(repository)..bindUser(saraAccount.user);
      final omar = MembershipProvider(repository)..bindUser(second.user);
      addTearDown(sara.dispose);
      addTearDown(omar.dispose);
      final queueId = provider.queue!.id;
      expect(
        (await repository.join(
          customer: saraAccount.user!,
          queueId: queueId,
        )).isOk,
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        (await repository.join(customer: second.user!, queueId: queueId)).isOk,
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(provider.waitingEntries.map((entry) => entry.customerName), [
        'Sara Hassan',
        'Omar Khalid',
      ]);
      expect(sara.isWaiting, isTrue);
      expect(omar.isWaiting, isTrue);
      await _shot(tester, 'customer-waiting-list');
      await _tap(tester, _filled('Call Next'));
      await tester.pumpAndSettle();
      expect(sara.isCalled, isTrue);
      expect(omar.isWaiting, isTrue);
      expect(provider.calledEntry!.customerName, 'Sara Hassan');
      expect(
        tester.widget<FilledButton>(_filled('Call Next')).onPressed,
        isNull,
      );
      await _shot(tester, 'call-next');
      await tester.tap(find.byTooltip('Back to Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('1 customers waiting'), findsOneWidget);
      expect(find.text('#01 · Sara Hassan'), findsOneWidget);
      await _shot(tester, 'dashboard-active');
      await _tap(tester, _filled('Manage Queue'));
      await tester.pumpAndSettle();
      await _tap(tester, _filled('Mark as Served'));
      await tester.pumpAndSettle();
      expect(sara.currentEntry!.status, MembershipStatus.served);
      expect(provider.calledEntry, isNull);
      expect(omar.isWaiting, isTrue);
      await _shot(tester, 'served');
      await _tap(tester, _filled('Call Next'));
      await tester.pumpAndSettle();
      expect(omar.isCalled, isTrue);
      await _tap(tester, _outlined('Skip'));
      await tester.pumpAndSettle();
      expect(omar.currentEntry!.status, MembershipStatus.skipped);
      expect(provider.calledEntry, isNull);
      expect(provider.waitingEntries, isEmpty);
      await _shot(tester, 'skipped');
      final context = tester.element(find.byType(QueueManagementScreen));
      Navigator.of(context).pushNamed('/create-queue');
      await tester.pumpAndSettle();
      expect(find.text('You already have a queue'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await _shot(tester, 'duplicate-queue-prevented');
    },
  );

  testWidgets('MOCK evidence: loading, load error, Retry recovery', (
    tester,
  ) async {
    final repository = _EvidenceRepository()..holdLoading = true;
    final provider = await _start(tester, repository, settle: false);
    expect(find.text('Loading your queue...'), findsOneWidget);
    await _shot(tester, 'dashboard-loading');
    repository.holdLoading = false;
    repository.failLoading = true;
    provider.retry();
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your queue'), findsOneWidget);
    await _shot(tester, 'dashboard-error');
    repository.failLoading = false;
    await _tap(tester, _filled('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No queue yet'), findsOneWidget);
    await _shot(tester, 'dashboard-retry-recovered');
  });

  testWidgets('MOCK evidence: called customer update failure and retry', (
    tester,
  ) async {
    final repository = _EvidenceRepository(seedSampleData: true);
    final provider = await _start(tester, repository);
    await _tap(tester, _filled('Manage Queue'));
    await tester.pumpAndSettle();
    final gate = Completer<OperationResult>();
    repository.finishGate = gate;
    await _tap(tester, _filled('Mark as Served'));
    gate.complete(OperationResult.failure(OperationError.failed));
    await tester.pumpAndSettle();
    expect(provider.calledEntry!.customerName, 'Ahmed Ali');
    expect(find.textContaining('Ahmed Ali is still called.'), findsOneWidget);
    await _shot(tester, 'management-update-error');
    repository.finishGate = null;
    await _tap(tester, _filled('Retry update'));
    await tester.pumpAndSettle();
    expect(provider.calledEntry, isNull);
    expect(find.text('#09 Ahmed Ali — Served'), findsOneWidget);
    await _shot(tester, 'management-update-retry-recovered');
  });
}
