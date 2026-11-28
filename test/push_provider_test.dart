import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe463_group7_project/models/queue_data.dart';
import 'package:swe463_group7_project/providers/push_provider.dart';
import 'package:swe463_group7_project/repositories/repositories.dart';
import 'package:swe463_group7_project/services/push_service.dart';

const customerA = AppUser(
  id: 'customer-a',
  name: 'Customer A',
  email: 'a@example.com',
  role: UserRole.customer,
);
const customerB = AppUser(
  id: 'customer-b',
  name: 'Customer B',
  email: 'b@example.com',
  role: UserRole.customer,
);
const provider = AppUser(
  id: 'provider-1',
  name: 'Provider',
  email: 'p@example.com',
  role: UserRole.provider,
);

// A push service the tests control: no Firebase Cloud Messaging is involved.
class FakePushService extends PushService {
  FakePushService({
    this.permission = PushPermission.granted,
    this.token = 'token-1',
  });

  PushPermission permission;
  String? token;
  Object? tokenError;
  int permissionRequests = 0;
  int deletions = 0;
  final StreamController<String> refreshes = StreamController<String>();
  final List<String> calls = [];

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    calls.add('permission');
    return permission;
  }

  @override
  Future<String?> getToken() async {
    calls.add('token');
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async {
    deletions++;
    calls.add('delete');
  }
}

// Provider tests for device registration: who is asked for permission, where
// the token is saved, and what happens on refresh, sign-out and account switch.
void main() {
  late AuthRepository accounts;
  late FakePushService push;
  late PushProvider provider0;

  setUp(() {
    accounts = AuthRepository(seedDemoAccounts: false);
    push = FakePushService();
    provider0 = PushProvider(push, accounts);
  });

  tearDown(() {
    provider0.dispose();
  });

  test('a customer is asked for permission and the token is saved', () async {
    provider0.bindUser(customerA);
    await pumpEventQueue();

    expect(push.permissionRequests, 1);
    expect(accounts.deviceTokenOf('customer-a'), 'token-1');
    expect(provider0.status, PushStatus.enabled);
  });

  test('a provider is never asked and no token is saved', () async {
    provider0.bindUser(provider);
    await pumpEventQueue();

    expect(push.permissionRequests, 0);
    expect(accounts.deviceTokenOf('provider-1'), isNull);
    expect(provider0.status, PushStatus.idle);
  });

  test('refused permission saves nothing', () async {
    push.permission = PushPermission.denied;
    provider0.bindUser(customerA);
    await pumpEventQueue();

    expect(provider0.status, PushStatus.denied);
    expect(accounts.deviceTokenOf('customer-a'), isNull);
  });

  test(
    'the default push service reports notifications as unavailable',
    () async {
      final plain = PushProvider(const PushService(), accounts)
        ..bindUser(customerA);
      await pumpEventQueue();

      expect(plain.status, PushStatus.unavailable);
      expect(accounts.deviceTokenOf('customer-a'), isNull);
      plain.dispose();
    },
  );

  test('a missing token or a failing push service shows an error', () async {
    push.token = null;
    provider0.bindUser(customerA);
    await pumpEventQueue();
    expect(provider0.status, PushStatus.error);

    push.token = 'token-2';
    provider0.retry();
    await pumpEventQueue();
    expect(provider0.status, PushStatus.enabled);
    expect(accounts.deviceTokenOf('customer-a'), 'token-2');

    final failing = FakePushService()..tokenError = StateError('no network');
    final other = PushProvider(failing, accounts)..bindUser(customerB);
    await pumpEventQueue();
    expect(other.status, PushStatus.error);
    other.dispose();
  });

  test('a refreshed token replaces the saved one', () async {
    provider0.bindUser(customerA);
    await pumpEventQueue();

    push.refreshes.add('token-new');
    await pumpEventQueue();

    expect(accounts.deviceTokenOf('customer-a'), 'token-new');
  });

  test('signing out invalidates this device and stops saving tokens', () async {
    provider0.bindUser(customerA);
    await pumpEventQueue();

    provider0.bindUser(null);
    await pumpEventQueue();
    push.refreshes.add('token-late');
    await pumpEventQueue();

    expect(push.deletions, 1);
    expect(provider0.status, PushStatus.idle);
    expect(accounts.deviceTokenOf('customer-a'), 'token-1');
  });

  test('a new account on the same device gets its own token', () async {
    provider0.bindUser(customerA);
    await pumpEventQueue();

    push.token = 'token-b';
    provider0.bindUser(customerB);
    await pumpEventQueue();

    // The old token is deleted before the new one is read.
    expect(push.calls, [
      'permission',
      'token',
      'delete',
      'permission',
      'token',
    ]);
    expect(accounts.deviceTokenOf('customer-a'), 'token-1');
    expect(accounts.deviceTokenOf('customer-b'), 'token-b');
  });

  test('a token that arrives after sign-out is not saved', () async {
    final gate = Completer<void>();
    final slow = _SlowPushService(gate);
    final slowProvider = PushProvider(slow, accounts)..bindUser(customerA);
    await pumpEventQueue();

    slowProvider.bindUser(null);
    gate.complete();
    await pumpEventQueue();

    expect(accounts.deviceTokenOf('customer-a'), isNull);
    slowProvider.dispose();
  });
}

class _SlowPushService extends FakePushService {
  _SlowPushService(this.gate);
  final Completer<void> gate;

  @override
  Future<String?> getToken() async {
    await gate.future;
    return 'token-slow';
  }
}
