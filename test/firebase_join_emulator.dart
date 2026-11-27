// Registers the existing Firebase web implementations for flutter test.
// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:swe463_group7_project/logic/queue_rules.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/repositories/firebase_auth_repository.dart';
import 'package:swe463_group7_project/repositories/firebase_queue_repository.dart';

const _runEmulatorTest = bool.fromEnvironment('QUEUELESS_FIREBASE_EMULATOR');
const _projectId = 'demo-queueless-phase4';

Future<(AppUser, FirebaseQueueRepository, FirebaseFirestore)> _createAccount(
  String name,
  UserRole role,
) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:123456789:web:123456789',
      messagingSenderId: '123456789',
      projectId: _projectId,
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 19099);
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.settings = const Settings(webExperimentalForceLongPolling: true);
  firestore.useFirestoreEmulator('127.0.0.1', 18081);
  final email = '$name@example.com';
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: 'emulator-password',
  );
  final account = AppUser(
    id: credential.user!.uid,
    name: name,
    email: email,
    role: role,
  );
  await firestore.collection('users').doc(account.id).set({
    'name': account.name,
    'email': account.email,
    'role': account.role.name,
  });
  return (account, FirebaseQueueRepository(firestore: firestore), firestore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebaseCoreWeb.registerWith(webPluginRegistrar);
  FirebaseAuthWeb.registerWith(webPluginRegistrar);
  FirebaseFirestoreWeb.registerWith(webPluginRegistrar);

  test(
    'Firestore serializes joins, calls and finishes',
    () async {
      final (provider, providerRepo, providerFirestore) = await _createAccount(
        'provider',
        UserRole.provider,
      );
      final created = await providerRepo.createQueue(
        provider: provider,
        name: 'Emulator queue',
        description: '',
        averageServiceMinutes: 5,
      );
      expect(created.isOk, isTrue, reason: created.message);
      await providerFirestore.disableNetwork();

      final (first, firstRepo, firstFirestore) = await _createAccount(
        'first',
        UserRole.customer,
      );
      final (second, secondRepo, secondFirestore) = await _createAccount(
        'second',
        UserRole.customer,
      );

      final results = await Future.wait([
        firstRepo.join(customer: first, queueId: provider.id),
        secondRepo.join(customer: second, queueId: provider.id),
      ]);
      expect(results.map((result) => result.isOk), everyElement(isTrue));
      await firstFirestore.terminate();
      await secondFirestore.terminate();

      final (third, thirdRepo, firestore) = await _createAccount(
        'third',
        UserRole.customer,
      );
      final duplicates = await Future.wait([
        thirdRepo.join(customer: third, queueId: provider.id),
        thirdRepo.join(customer: third, queueId: provider.id),
      ]);
      expect(
        duplicates.map((result) => result.error),
        unorderedEquals([null, OperationError.alreadyMember]),
      );

      final entries = await firestore
          .collection('entries')
          .get(const GetOptions(source: Source.server));
      expect(
        entries.docs.map((entry) => entry.data()['ticketNumber']),
        unorderedEquals([1, 2, 3]),
      );
      expect(
        entries.docs.map((entry) => entry.data()['customerId']),
        unorderedEquals([first.id, second.id, third.id]),
      );
      final auth = FirebaseAuth.instanceFor(app: Firebase.app('third'));
      final accounts = FirebaseAuthRepository(auth: auth, firestore: firestore);
      expect((await accounts.authStateChanges().first)?.id, third.id);
      await accounts.signOut();
      expect(await accounts.authStateChanges().first, isNull);

      await auth.createUserWithEmailAndPassword(
        email: 'missing-profile@example.com',
        password: 'emulator-password',
      );
      await auth.signOut();
      final missingProfile = await accounts.signIn(
        email: 'missing-profile@example.com',
        password: 'emulator-password',
      );
      expect(missingProfile.isOk, false);
      expect(auth.currentUser, isNull);
      await expectLater(
        firestore
            .collection('entries')
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await firestore.terminate();

      await providerFirestore.enableNetwork();
      final calls = await Future.wait([
        providerRepo.callNext(provider: provider, queueId: provider.id),
        providerRepo.callNext(provider: provider, queueId: provider.id),
      ]);
      expect(calls.where((result) => result.isOk), hasLength(1));

      final finishes = await Future.wait([
        providerRepo.finishCalled(
          provider: provider,
          queueId: provider.id,
          outcome: MembershipStatus.served,
        ),
        providerRepo.finishCalled(
          provider: provider,
          queueId: provider.id,
          outcome: MembershipStatus.skipped,
        ),
      ]);
      expect(finishes.where((result) => result.isOk), hasLength(1));

      final updated = await providerFirestore
          .collection('entries')
          .get(const GetOptions(source: Source.server));
      final statuses = updated.docs.map((doc) => doc.data()['status']).toList();
      expect(statuses.where((status) => status == 'waiting'), hasLength(2));
      expect(
        statuses.where((status) => ['served', 'skipped'].contains(status)),
        hasLength(1),
      );
    },
    skip: !_runEmulatorTest,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
