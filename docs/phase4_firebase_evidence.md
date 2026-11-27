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

Production deployment is pending approval. The course disclosure for Codex assistance is in [README.md](../README.md#licenses-and-ai-use).

## Demonstration

- Explain why a Firebase account also needs a Firestore profile and how the profile's role selects the home screen.
- Explain what the transaction saves together and why simultaneous customers cannot share a newly allocated ticket under normal app operation.
- Show the emulator test that creates concurrent joins and sends overlapping provider actions.
