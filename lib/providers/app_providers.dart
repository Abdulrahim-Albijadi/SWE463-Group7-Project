import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/repositories.dart';
import 'auth_provider.dart';
import 'membership_provider.dart';
import 'provider_queue_provider.dart';
import 'queue_provider.dart';

// Creates the shared Providers once. The other three follow the signed-in
// user, so logging out clears every queue and ticket from memory.
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.authRepository,
    required this.queueRepository,
    required this.child,
  });
  final AuthRepository authRepository;
  final QueueRepository queueRepository;
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authRepository),
      ),
      ChangeNotifierProxyProvider<AuthProvider, QueueProvider>(
        lazy: false,
        create: (_) => QueueProvider(queueRepository),
        update: (_, auth, queues) => queues!..bindUser(auth.currentUser),
      ),
      ChangeNotifierProxyProvider<AuthProvider, MembershipProvider>(
        lazy: false,
        create: (_) => MembershipProvider(queueRepository),
        update: (_, auth, membership) =>
            membership!..bindUser(auth.currentUser),
      ),
      ChangeNotifierProxyProvider<AuthProvider, ProviderQueueProvider>(
        lazy: false,
        create: (_) => ProviderQueueProvider(queueRepository),
        update: (_, auth, providerQueue) =>
            providerQueue!..bindUser(auth.currentUser),
      ),
    ],
    child: child,
  );
}