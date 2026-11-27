# Local Notification Sender

## Purpose

Run the QueueLess notification sender locally while the Firebase project
remains on the Spark plan. No Cloud Functions deployment is required for
this mode.

The sender reuses the notification logic in `functions/notifications.js`.
It watches one queue and sends only to the configured test customer.

## Requirements

- Node.js and npm.
- Access to the `queueless-group7` Firebase project.
- A Firebase service account JSON key stored outside the repository.
- The Android application with notification permission granted.
- A non-empty `fcmToken` on the customer's Firestore user document.

Never commit the service account key, include it in Flutter assets, or
share its contents.

## Setup

From the project root:

```powershell
npm ci --prefix functions
```

In the same PowerShell terminal, configure:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\outside-repository\service-account.json"
$env:QUEUELESS_QUEUE_ID = "QUEUE_DOCUMENT_ID"
$env:QUEUELESS_CUSTOMER_ID = "CUSTOMER_USER_DOCUMENT_ID"
```

These environment variables apply to the current terminal session.

## Preview Mode

```powershell
node functions/local_sender.js
```

Preview mode logs planned notifications without sending messages or
updating notification flags.

## Send Mode

Stop preview mode with Ctrl+C, then run:

```powershell
node functions/local_sender.js --send
```

Keep this process running and connected to the internet.
Stop it with Ctrl+C after testing.

Send mode can update notification flags on entries and remove invalid
FCM tokens. Other customers are excluded by the configured customer ID;
their log results may show `no-token` even if they have a stored token.

## Verified Device Test — November 27, 2026

Environment:
- HONOR NTH NX9, Android 13.
- Customer application running on the physical Android device.
- Provider application running separately in Chrome.
- Queue: Badr Android Test.
- Customer ticket: #10.

Verified sequence:
1. Joined the queue from the Android application.
2. Preview mode detected the new waiting ticket and planned a near-turn alert.
3. Started send mode and placed the Android application in the background.
4. Called ticket #6 from the provider application.
5. Received "Your turn is near" for ticket #10 on Android.
6. Marked ticket #6 as served and called ticket #10.
7. Received "It's your turn!" for ticket #10 on Android.
8. Opened the customer application and confirmed the Called state.
9. Marked ticket #10 as served and confirmed the Served state on Android.

The sender logged `sent` for both notification types.

## Automated Validation

- `node --check functions/local_sender.js`: passed.
- Notification logic tests: 22 passed.
- `flutter analyze`: no issues found.
- Flutter tests: 144 passed.
- Added four customer screen regression tests covering 0, 1, 2, and 3
  customers ahead.

The JavaScript tests exercise the shared notification logic.
The local runner was checked through syntax validation and the live
device test above.

## Limitations

- This is a local runner, not an always-on hosted service.
- Automatic sending stops when the process, laptop, or connection stops.
- The first snapshot establishes a baseline; existing tickets are not
  replayed when the sender starts.
- Only subsequent ticket creation and status changes trigger processing.
  Token registration alone does not trigger a retry.
- A failed send can be retried by a later qualifying entry change.
  Durable delivery and recovery after interruption are not guaranteed.
- The live test verified Android background notification delivery.
  Foreground system notifications and notification-tap routing were not
  verified.
- Cloud Functions were not deployed to the Firebase project.

The test used Node.js 22.14.0. Installation reported Node engine warnings
for two transitive Realtime Database packages. Admin SDK imports,
Firestore access, and the notification delivery checks passed; those
engine warnings remain unresolved.