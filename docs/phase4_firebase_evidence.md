# QueueLess Phase 4 Firebase contribution

**Assigned to Abdulrahim Albijadi.** Scope includes Firebase configuration, account handling, Firestore rules, and queue synchronization.

| Area | Change | Evidence |
| --- | --- | --- |
| Accounts | Empty login fields, role-based session restoration, and cleanup when a profile cannot load or the listener fails | [Auth provider](../lib/providers/auth_provider.dart), [Firebase auth repository](../lib/repositories/firebase_auth_repository.dart), [account widget tests](../test/widget_test.dart) |
| Customer queue operations | Ticket, per-queue counter, and customer membership saved atomically. Leaving checks the entry's current status in a transaction. | [Firebase queue repository](../lib/repositories/firebase_queue_repository.dart), [backend emulator test](../test/firebase_join_emulator.dart) |
| Provider queue operations | Queue creation and status updates use transactions. Call Next records the currently called entry with the status change. Finish checks the specific entry before updating it. | [Firebase queue repository](../lib/repositories/firebase_queue_repository.dart), [backend emulator test](../test/firebase_join_emulator.dart) |
| Firestore and setup | Rules authorize synchronized writes, and the repository excludes local API-key configuration. | [Firestore rules](../firestore.rules), [setup and emulator command](../README.md) |

| Backend emulator check | Result |
| --- | --- |
| Two customers join concurrently | Each receives a distinct ticket. |
| One customer submits two concurrent joins | One entry is created. The other request returns `alreadyMember`. |
| Existing session, logout, and missing profile | Session resolves to the expected account. Logout clears it. Login with a missing profile fails and clears the Firebase session. |
| Signed-out Firestore read | Entry query returns `permission-denied`. |
| Concurrent Call Next requests | One request succeeds. |
| Concurrent Serve and Skip requests | One request succeeds. Exactly one entry reaches a terminal status and the other two remain waiting. |

The emulator command in the README uses a local demo project. On this machine, Chrome loaded the same Firebase web SDK version from a temporary local copy because the Firebase CDN timed out. A production rollout requires the app and rules to be released together. Existing queues can seed their first counter from ticket history. Firestore rules enforce subsequent counter increments, but cannot calculate the maximum legacy ticket across a collection. Review existing queue data before rollout.

On 27 November 2026, a read-only production audit confirmed Email/Password sign-in is enabled and the Android, iOS, and browser keys each have application and API restrictions. The audit found five queues and 16 entries, with no duplicate ticket numbers within a queue, duplicate active memberships, or queues with multiple called entries. The audited project had no ticket counter documents yet.

The updated Firestore rules were deployed to `queueless-group7` on 27 November 2026 after team verification. Cloud Functions were not deployed. Release APK preparation and final release verification remain pending. The course disclosure for Codex assistance is in [README.md](../README.md#licenses-and-ai-use).

## Demonstration

- Explain why a Firebase account also needs a Firestore profile and how the profile's role selects the home screen.
- Explain what the transaction saves together and why simultaneous customers cannot share a newly allocated ticket under normal app operation.
- Show the emulator test that creates concurrent joins and sends overlapping provider actions.

## Integration verification — 27 November 2026

Verification performed by Bader Alshehri using application code based on
`42667d8`, after the Firebase synchronization changes were merged.

### Automated checks

- Flutter 3.47.9 / Dart 3.13.7.
- `flutter analyze`: no issues found.
- `flutter test`: all 147 tests passed.
- Chrome queue-rule tests: all 16 passed.
- The separate Firebase emulator integration test passed, with script
  exit code 0.

The emulator scenario verified distinct tickets for concurrent joins,
prevention of duplicate active membership, account/session checks,
signed-out read rejection, one successful concurrent Call Next request,
and one successful competing Serve/Skip request.

Rejected competing provider writes logged permission-denied messages.
The assertions confirmed the expected successful-request counts and
final entry states. These results do not establish exhaustive security
coverage or concurrent operation on production devices.

### Production rules deployment

Command:

```powershell
npx firebase-tools deploy --only firestore:rules --project queueless-group7
```

The CLI confirmed successful compilation and release of `firestore.rules`.
Only Firestore rules were deployed.

### Live Android and Chrome checks

The updated customer application ran on a physical HONOR NTH NX9
(Android 13). The provider application ran separately in Chrome.
Both used `--dart-define-from-file=firebase.local.json`.

Verified against the dedicated Badr Android Test queue:

- The Android application restored the saved customer session.
- A new join created waiting ticket #11, following the previous #10.
  Position was 1, with zero ahead and a zero-minute estimate.
- Chrome displayed the new customer.
- Call Next changed #11 to Called in both sessions and disabled
  another Call Next.
- Mark as Served changed #11 to Served and left nobody called.
- Rejoining created #12; Call Next followed by Skip updated the
  customer screen to Skipped.
- A subsequent join, confirmed leave, and rejoin produced the expected
  Left and new Waiting states, with matching provider-list updates.
- With the local sender running and Android in the background,
  calling the latest ticket delivered "It's your turn!".
  The sender logged `called` with outcome `sent`, and the customer
  application displayed Called.

Near-turn background delivery was verified earlier that day before
the backend update; this post-update notification check specifically
retested called delivery.

### Local Windows test-tool correction

The first browser test attempts did not run because the Flutter test
server returned 404 for local CanvasKit JavaScript and WASM files,
although those files existed in the SDK cache.

In the local Flutter SDK file
`packages/flutter_tools/lib/src/test/flutter_web_platform.dart`,
inside `_localCanvasKitHandler`, the following line:

```dart
final String fullPath = _fileSystem.path.fromUri(request.url);
```

was replaced with:

```dart
final String fullPath = request.url.path;
```

This preserves URL separators for the handler's `canvaskit/` prefix
check on Windows. The original file was backed up, then
`bin/cache/flutter_tools.stamp` was removed and `flutter --version`
rebuilt the tool.

The Chrome and emulator passes above used this locally corrected SDK.
No Flutter SDK files are included in the project commit.

An earlier native test attempt was interrupted by insufficient disk
space. After space was freed, all 147 standard tests passed.
An initial Android run also logged network-unreachable errors;
the live checks listed above were performed after connectivity returned.

### Remaining release work

- Prepare and test the intended release APK.
- Verify setup from a clean checkout of the final revision.
- Complete final screenshots, contribution evidence, and the report.
- Create `final-submission` only after final verification.

The local notification sender still requires a running, connected
computer. Foreground system notifications and notification-tap routing
are not claimed as verified.