# QueueLess

**SWE 463 — Group 7 | Phase 3: Working Flutter Prototype**

QueueLess is a Flutter virtual queue application. Customers browse services, join or leave a queue, and track their ticket, customers ahead, estimated wait, and turn status. Providers create a queue, view waiting customers, call the next customer, and mark the called customer as served or skipped.

The current application uses Firebase Authentication, Cloud Firestore, and Provider. Near-turn and called alerts work inside the application. Background push notifications are not implemented.

## Team

| Member | Student ID | Assigned area |
| --- | --- | --- |
| Abdulrahim Albijadi | 202260760 | Authentication, Firebase data integration, and profile |
| Omar Alshehri | 202177130 | Provider dashboard and queue management |
| Bader Alshehri | 202178070 | Customer interface and navigation |
| Bader Almutairi | 202159390 | Queue rules, waiting estimates, and notifications |

These are assigned areas. The Phase 3 report must record each member's actual completed work with specific commits, issues, or pull requests.

## Phase 3 feature progress

| ID | Approved essential feature | Status | Current behavior |
| --- | --- | --- | --- |
| F1 | Accounts and roles | Implemented | Firebase email/password registration and sign-in, Customer/Provider roles, profile display, role-specific navigation, and logout. |
| F2 | Queue creation and management | Implemented | Create one queue per provider; display waiting customers; Call Next, Mark as Served, and Skip. |
| F3 | Join and leave | Implemented | Browse queues, view details, join, leave with confirmation while waiting, and rejoin with a new ticket. |
| F4 | Live queue tracking | Implemented | Firestore snapshot subscriptions update queue and membership data; screens display ticket and status information. Simultaneous operation on two devices remains to be verified. |
| F5 | Estimated waiting time | Implemented | Customers ahead multiplied by the provider's average service duration; the called customer counts as ahead. |
| F6 | Queue notifications | In progress | Near-turn and called in-app banners/messages work. FCM device registration, a trusted sender, and background push delivery are not implemented. |

**Completion: 5 of 6 essential features implemented (approximately 83%); F6 is partial and is not counted as complete.** This feature count does not imply that every edge case has been verified.

QR joining, Queue History, Pause/Close Queue, and Basic Queue Statistics were excluded optional features in the approved Phase 2 scope. They are not claimed as implemented core features.

## Screens and navigation

The application has nine major screens:

- Shared: Login, Register, and Profile.
- Customer: Customer Home, Queue Details, and My Queue.
- Provider: Provider Dashboard, Create Queue, and Queue Management.

Customer flow: Login/Register → Customer Home → Queue Details → Join Queue → My Queue. Home and My Queue are accessible through bottom navigation.

Provider flow: Login/Register → Provider Dashboard → Create Queue → Queue Management. Dashboard and Manage Queue are accessible through bottom navigation. Shared Profile provides account information and logout confirmation.

## State management and data

`AppProviders` supplies `AuthProvider`, `QueueProvider`, `MembershipProvider`, and `ProviderQueueProvider`. Authentication changes bind the shared providers to the current user. Temporary form and interaction state uses local `setState` and controllers.

`main.dart` initializes Firebase with `DefaultFirebaseOptions.currentPlatform` and injects `FirebaseAuthRepository` and `FirebaseQueueRepository`. The in-memory repositories remain available for isolated tests; normal application startup uses Firebase.

| Data | Current source |
| --- | --- |
| Credentials | Firebase Authentication |
| User name, email, and role | Firestore `users/{uid}` |
| Provider queue | Firestore `queues/{providerUid}` |
| Customer ticket and membership status | Firestore `entries/{entryId}` |
| Customers ahead and estimated wait | Derived from queue entries and average service duration |
| Near-turn/called messages | In-app membership alert stream and screen state |

Passwords are handled by Firebase Authentication and are not written to the application's Firestore collections. Firestore entries are stored in a top-level `entries` collection, rather than the nested collection proposed in Phase 2.

### Queue rules

- A customer may have one active membership; a provider may create one queue.
- A successful join creates a waiting entry with a fixed ticket number.
- Queue order follows joining time; a ticket number stays fixed as customers ahead change.
- Leave is allowed while waiting and changes the status to `left`.
- Call Next calls the first waiting customer; only one customer may be called at a time.
- Only the called customer can be marked `served` or `skipped`.
- Serving or skipping does not automatically call the next customer.
- `estimatedWait = customersAhead × averageServiceMinutes`.
- The currently called customer counts as ahead until served or skipped.

## Setup and run

### Prerequisites

- Flutter with a bundled Dart SDK satisfying `^3.13.1`, as declared in `pubspec.yaml`.
- For the verified Android path: an Android development toolchain and an emulator or USB-debugging-enabled physical device.
- Internet access and access to the configured Firebase project, or an appropriately configured replacement Firebase project.
- Firebase configuration matching the selected target platform. The entry point imports `lib/firebase_options.dart`; retain or supply the appropriate configuration before running.
- Firebase Authentication with Email/Password enabled and a Cloud Firestore database with the intended access rules. A team member with Firebase project access must confirm the configuration for a fresh environment.

The Android package used in the manual run was `com.example.swe463_group7_project`. If the configured API key restricts Android applications, its allowed package and signing-certificate fingerprint must match the build being tested. Do not remove restrictions to bypass a configuration mismatch.

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with an ID reported by `flutter devices`. Android on a physical HONOR device is the manually verified platform. Other platform builds and startup from a clean checkout have not yet been verified in this testing session.

### Test accounts

Create new test accounts through **Create Account** using distinct email addresses and select the required Customer or Provider role. Keep passwords private.

The sign-in screen currently pre-fills and advertises old sample credentials. Those accounts are seeded only by the in-memory auth repository; they are not automatically created in Firebase. Replace the prefilled values with a registered Firebase account or register a new account.

## Testing instructions

Use a dedicated provider queue to avoid changing another team member's demonstration data. Example setup: queue name `Badr Android Test`, description `Phase 3 Android verification`, and average service duration `5` minutes. Ticket numbers depend on existing activity; the examples below assume a new, empty queue.

1. Register a Provider and create the test queue. Confirm that its dashboard shows the queue and no waiting customers.
2. Log out, register a Customer, open the queue, and join. Confirm a waiting ticket and the My Queue screen.
3. Choose Leave Queue, cancel the confirmation, and confirm the ticket remains. Then confirm leaving and check the `left` state. Rejoin and confirm a new ticket.
4. Switch to the Provider account, open Manage Queue, and choose Call Next. Switch back to the Customer and confirm `called` and the turn message.
5. Mark that ticket as served from the Provider account. Confirm `served` and the completion message in the Customer account.
6. Rejoin and repeat Call Next followed by Skip. Confirm `skipped` and the missed-turn message in the Customer account.
7. For the estimate test, start with no active entries. Join using three distinct Customer accounts, logging out between accounts without leaving their queues. On the third account, confirm two customers ahead, a 10-minute estimate, and the near-turn notice.
8. Call and serve the first customer. On the third account, confirm its ticket number stays fixed while the count becomes one ahead and the estimate becomes 5 minutes.
9. Call the second customer without serving them. Confirm the third account still shows one ahead and 5 minutes. Serve the second customer; the third account should remain waiting with zero ahead and zero minutes until Call Next is explicitly used.
10. Verify logout and account switching return to the expected screens without a stale profile-listener error.

Switching accounts on one device verifies persisted results across sessions. Use two separately configured devices for the remaining simultaneous live-update check.

### Recorded validation

The following results were reported during the Android verification session on 13 November 2026:

- `flutter analyze`: no issues found.
- `flutter test`: all 69 tests passed before merging the auth listener fix.
- Staged diff checks passed for the reviewed code changes.
- Firebase registration for both roles, provider queue creation, logout, and account switching succeeded.
- Join, leave, rejoin, called, served, and skipped flows succeeded.
- Three-customer checks confirmed 2 ahead → 10 minutes, 1 ahead → 5 minutes, and 0 ahead → 0 minutes with a fixed ticket number.
- The called customer remained included in customers ahead; serving did not automatically call the next customer.
- Near-turn and called in-app messages were observed.

These results describe the tested revision and session; rerun the commands after further code changes.

## Loading, empty, validation, and failure states

The inspected provider screens include loading and load-error states with Retry, no-queue and no-waiting-customer states, required queue-field and positive-duration validation, creating/busy states, and action success/failure feedback. The inspected authentication screens include required-field checks, password confirmation, busy controls, and failure text. Customer empty, waiting, near-turn, called, served, skipped, and left states were observed during manual testing.

## Known issues and remaining work

- **Push notifications:** no `firebase_messaging` or background push implementation is present. In-app messages do not provide notifications while the app is closed or in the background.
- **Concurrent ticket allocation:** the Firebase repository calculates ticket numbers client-side. Simultaneous joins may receive duplicate numbers; transactional allocation remains future work.
- **Concurrency verification:** the single-active-membership and single-called-customer rules need review and testing under simultaneous requests. Current manual checks used sequential actions.
- **Fresh setup:** clean-checkout startup and the completeness of Firebase setup instructions must be verified before submission.
- **Multiple devices/platforms:** simultaneous two-device updates and non-Android builds have not been verified in the recorded session.
- **Old demo text:** the Login screen still pre-fills and displays sample account credentials that are not guaranteed to exist in Firebase.
- **Failure-path verification:** controlled network failures and all retry/validation variants have not been manually exercised in the recorded session.
- **Submission evidence:** finalize the Phase 3 PDF, verify each member's contribution evidence, and create the `phase-3` tag only when the submitted revision is ready. This README does not claim the tag already exists.

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Firebase startup, theme, routes, authentication/profile screens, and in-app alert display |
| `lib/firebase_options.dart` | Platform-specific Firebase client configuration |
| `lib/models/queue_data.dart` | User, queue, membership, and notification models |
| `lib/logic/queue_rules.dart` | Queue checks, ordering, and derived queue logic |
| `lib/providers/` | Shared authentication, queues, membership, and provider state |
| `lib/repositories/repositories.dart` | In-memory repository implementations for isolated testing |
| `lib/repositories/firebase_auth_repository.dart` | Firebase Authentication and Firestore profile integration |
| `lib/repositories/firebase_queue_repository.dart` | Firestore queue and membership reads/writes and subscriptions |
| `lib/screens/customer_screens.dart` | Customer Home, Queue Details, and My Queue |
| `lib/screens/provider_screens.dart` | Provider Dashboard, Create Queue, and Queue Management |
| `lib/widgets/provider/` | Reusable provider interface widgets |
| `test/` | Automated Flutter tests |

## Packages

| Package | Declared constraint | Purpose |
| --- | --- | --- |
| Flutter SDK | SDK | Material interface, navigation, and framework |
| `cupertino_icons` | `^1.0.8` | Cupertino icon assets |
| `provider` | `^6.1.5+1` | Shared state and dependency injection |
| `firebase_core` | `^5.1.0` | Firebase initialization |
| `firebase_auth` | `^7.0.1` | Email/password authentication |
| `cloud_firestore` | `^7.1.0` | Stored profiles, queues, entries, and snapshot updates |
| `flutter_test` | SDK | Automated tests |
| `flutter_lints` | `^6.0.0` | Static analysis rules |

These are `pubspec.yaml` constraints; `pubspec.lock` records resolved versions. Firebase Messaging and Cloud Functions are planned, not current application dependencies.

## Links and references

- [Figma designs](https://www.figma.com/design/sVVahJW10wMCvfVPgKibRQ/QueueLess-Phase-2?node-id=0-1)
- [GitHub repository](https://github.com/Abdulrahim-Albijadi/SWE463-Group7-Project)
- [Flutter documentation](https://docs.flutter.dev)
- [Provider package](https://pub.dev/packages/provider)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Cloud Firestore](https://firebase.google.com/docs/firestore)
- [Firebase Cloud Messaging — planned work](https://firebase.google.com/docs/cloud-messaging)
- [Cloud Functions Firestore triggers — planned work](https://firebase.google.com/docs/functions/firestore-events)

## Licenses and AI use

Retain third-party notices and review the LICENSE files for the resolved package versions before distribution. The Phase 2 reference record identifies Flutter as BSD 3-Clause, Provider as MIT, Material Icons as Apache License 2.0, Firebase documentation content as CC BY 4.0 with code samples under Apache License 2.0, and Figma as subject to its terms of service. Documentation licenses do not replace package licenses or Firebase service terms.

The team made the design and product decisions and is responsible for understanding and reviewing the submitted work. Figma AI and ChatGPT were used for some screen drafts, Flutter starter code examples, and suggestions. Claude was used to help structure the Phase 2 report and README and correct grammar. During Phase 3, ChatGPT assisted with debugging the customer smoke-test provider setup and Firebase profile-listener behavior, planning manual checks, and drafting this README from supplied code and reported results. Each member must ensure this disclosure also covers any other AI assistance used in their contribution. AI assistance is not evidence of a member's authorship or completed work.
