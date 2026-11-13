import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/queue_data.dart';
import '../logic/queue_rules.dart';
import 'repositories.dart';

import 'dart:async';

class FirebaseAuthRepository extends AuthRepository {
  FirebaseAuthRepository() : super(seedDemoAccounts: false);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Convert a Firestore profile into an app user.
  AppUser? _toAppUser(User user, Map<String, dynamic>? data) {
    if (data == null) return null;

    final role = switch (data['role']) {
      'customer' => UserRole.customer,
      'provider' => UserRole.provider,
      _ => null,
    };

    if (role == null) return null;

    return AppUser(
      id: user.uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? user.email ?? '',
      role: role,
    );
  }

  // Restore the signed-in user and listen for profile changes.
  @override
  Stream<AppUser?> authStateChanges() {
    late final StreamController<AppUser?> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    profileSubscription;
    var generation = 0;
    var cancelled = false;

    controller = StreamController<AppUser?>(
      onListen: () {
        authSubscription = _auth.authStateChanges().listen(
          (user) async {
            final currentGeneration = ++generation;
            final previousSubscription = profileSubscription;
            profileSubscription = null;
            await previousSubscription?.cancel();

            if (cancelled || currentGeneration != generation) return;

            if (user == null) {
              controller.add(null);
              return;
            }

            bool isCurrentUser() =>
                !cancelled &&
                currentGeneration == generation &&
                _auth.currentUser?.uid == user.uid;

            profileSubscription = _db
                .collection('users')
                .doc(user.uid)
                .snapshots()
                .listen(
                  (snapshot) {
                    if (isCurrentUser()) {
                      controller.add(_toAppUser(user, snapshot.data()));
                    }
                  },
                  onError: (Object error, StackTrace stackTrace) {
                    if (isCurrentUser()) {
                      controller.addError(error, stackTrace);
                    }
                  },
                );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!cancelled) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      onCancel: () async {
        cancelled = true;
        generation++;
        await authSubscription?.cancel();
        await profileSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  // Log in using Firebase Authentication.
  @override
  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;
      final document = await _db.collection('users').doc(user.uid).get();

      final appUser = _toAppUser(user, document.data());

      if (appUser == null) {
        await _auth.signOut();
        return AuthOutcome(
          OperationResult.failure(
            OperationError.failed,
            'User profile was not found.',
          ),
        );
      }

      return AuthOutcome(OperationResult.ok, appUser);
    } on FirebaseAuthException catch (e) {
      if ([
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-email',
      ].contains(e.code)) {
        return AuthOutcome(
          OperationResult.failure(OperationError.invalidCredentials),
        );
      }

      return AuthOutcome(OperationResult.failure(OperationError.failed));
    } catch (_) {
      return AuthOutcome(OperationResult.failure(OperationError.failed));
    }
  }

  // Register with Firebase Authentication and save the profile.
  @override
  Future<AuthOutcome> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    User? createdUser;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user!;
      final userEmail = createdUser.email ?? email.trim();

      await _db.collection('users').doc(createdUser.uid).set({
        'name': name.trim(),
        'email': userEmail,
        'role': role.name,
      });

      final appUser = AppUser(
        id: createdUser.uid,
        name: name.trim(),
        email: userEmail,
        role: role,
      );

      return AuthOutcome(OperationResult.ok, appUser);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return AuthOutcome(OperationResult.failure(OperationError.emailInUse));
      }

      if (e.code == 'weak-password') {
        return AuthOutcome(
          OperationResult.failure(
            OperationError.failed,
            'Please use a stronger password.',
          ),
        );
      }

      return AuthOutcome(OperationResult.failure(OperationError.failed));
    } catch (_) {
      // Avoid leaving an incomplete account after a failed profile write.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          await _auth.signOut();
        }
      }

      return AuthOutcome(OperationResult.failure(OperationError.failed));
    }
  }

  // Log out through Firebase.
  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
