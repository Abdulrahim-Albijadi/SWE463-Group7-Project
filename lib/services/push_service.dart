// Result of asking the user to allow notifications.
enum PushPermission { granted, denied, unsupported }


// FirebasePushService replaces these methods with the real calls. Nothing
// outside this folder depends on Firebase Cloud Messaging.
class PushService {
  const PushService();

  // Asks the user to allow notifications on this device.
  Future<PushPermission> requestPermission() async =>
      PushPermission.unsupported;

  // The token the sender uses to reach this device, or null when unavailable.
  Future<String?> getToken() async => null;

  // A new token, sent when the old one is replaced.
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  // Invalidates this device's token, so messages for the previous account
  // cannot reach a device that is used by someone else.
  Future<void> deleteToken() async {}
}