# Final release verification — 28 November 2026

Tester: Bader Alshehri.
Application source: `c94338e`.
Device: physical HONOR NTH NX9, Android 13.
Backend: Firebase project `queueless-group7`.

## Clean-checkout checks

A new clone at `F:\SWE463_Final_Check` was checked out at `c94338e`
on the existing configured Windows development machine.

- `flutter pub get`: succeeded.
- `flutter analyze`: no issues found.
- `flutter test`: all 147 tests passed.
- Flutter 3.47.9 / Dart 3.13.7.

This verifies a clean project checkout on the configured machine,
not setup on a completely new development machine.

## Release APK

Command:

```powershell
flutter build apk --release --dart-define-from-file=firebase.local.json
```

The release-mode APK built successfully, approximately 50.1 MB.
The repository uses its debug signing configuration for this build;
store signing is not claimed.

The exact APK was installed using `adb install -r`, which returned
`Success`. Launching it restored the saved customer session.

Preserved artifact: `Group07_QueueLess.apk`.

SHA-256:

```text
48EF4DF67DD8C007DCABE7FF8C7B8FBECA12C7A0DF6D835E57C1F99C40EB1FB3
```

APK permission inspection confirmed INTERNET, POST_NOTIFICATIONS,
ACCESS_NETWORK_STATE, WAKE_LOCK and FCM receive permissions.

## Manual release checks

| Scenario | Result |
| --- | --- |
| Join #15 | Waiting, position 1, zero ahead, zero-minute estimate; Chrome provider displayed the customer. |
| Background called notification | Local sender logged `called` / `sent`; notification arrived on Android; opening the app showed Called. |
| Serve #15 | Customer displayed Served; queue became empty. |
| Skip #16 | Rejoin, Call Next and Skip produced Skipped. |
| Leave #17 | Cancel preserved Waiting; confirmed leave produced Left and updated the provider list. |
| Native provider action #18 | Provider login on Android displayed #18; Call Next changed it to Called. |
| Customer #18 | Customer login displayed Called; Chrome provider served it; Android displayed Served. |
| Registration validation | Empty submission displayed field errors. |
| New provider | Registration reached the No queue yet dashboard. |
| Queue validation | Empty name/description and duration 0 were rejected. |
| Queue creation | Phase 4 Release Test was created, Open, with a five-minute duration and zero waiting customers. |

The local sender was running during the background notification check.
Cloud Functions were not deployed. Near-turn background delivery was
verified on 27 November; this release check specifically retested
called background delivery.

## Build environment adjustments

The successful Windows build used:

- `PUB_CACHE=F:\SWE463_PubCache`
- `ORG_GRADLE_PROJECT_kotlin.incremental=false`
- `ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy=in-process`

Gradle daemons were stopped, followed by `flutter clean` and
`flutter pub get`, before rebuilding. These settings addressed
cross-drive and Kotlin compilation-cache failures.

Kotlin plugin compatibility and Java deprecation/unchecked warnings
remained, but the recorded release build succeeded.

`npm ci --prefix functions` completed with zero reported vulnerabilities.
It also reported Node engine and deprecation warnings; their absence
is not claimed.

The earlier Chrome/emulator test passes used the local Flutter SDK
CanvasKit correction documented in `phase4_firebase_evidence.md`.

## Verification limits and final freeze

The APK corresponds to application source `c94338e`.
Documentation added afterward must not be described as a new APK build.

Foreground system notifications, notification-tap routing, native iOS,
simultaneous operation on two physical phones, and a complete manual
offline/reconnect matrix remain unverified.

The local sender requires a running, connected trusted computer.

Create `final-submission` only after final documentation is merged,
required checks pass, and repository/report access is verified.
The final tag and its revision must be recorded before submission.