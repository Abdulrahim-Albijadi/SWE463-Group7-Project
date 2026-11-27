// Platform IDs from FlutterFire. Supply API keys using Dart defines.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('QUEUELESS_FIREBASE_WEB_API_KEY'),
    appId: '1:153128067184:web:e9baf00db42400613014b5',
    messagingSenderId: '153128067184',
    projectId: 'queueless-group7',
    authDomain: 'queueless-group7.firebaseapp.com',
    storageBucket: 'queueless-group7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('QUEUELESS_FIREBASE_ANDROID_API_KEY'),
    appId: '1:153128067184:android:94da56fe27ceaabd3014b5',
    messagingSenderId: '153128067184',
    projectId: 'queueless-group7',
    storageBucket: 'queueless-group7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('QUEUELESS_FIREBASE_IOS_API_KEY'),
    appId: '1:153128067184:ios:0a25bf7d01ebcc383014b5',
    messagingSenderId: '153128067184',
    projectId: 'queueless-group7',
    storageBucket: 'queueless-group7.firebasestorage.app',
    iosBundleId: 'com.example.swe463Group7Project',
  );
}
