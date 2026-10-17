# QueueLess

**SWE 463 — Group 7 | Phase 2: User Interface and Technical Design**

QueueLess is a Flutter app for campus service queues. Customers can find queues, join or leave, check their ticket and estimated wait, and receive turn alerts. Providers can create and manage a queue, call customers, and mark them as served or skipped.

## Team

- Abdulrahim Albijadi — Authentication, profile, and integration
- Bader Alshehri — Customer screens and navigation diagram
- Omar Alshehri — Provider screens
- Bader Almutairi — Queue rules, state plan, and documentation

Actual completed contributions and evidence are recorded in the Phase 2 report.

## Phase 2

The deliverables include Figma designs, a navigation flow, technical plans, and a Flutter starter with nine screens: Login, Register, Profile, Customer Home, Queue Details, My Queue, Provider Dashboard, Create Queue, and Queue Management.

The starter uses sample data; full Firebase integration and push notifications are planned for later phases. **Integration and successful execution have not yet been verified.**

### What this phase adds

- **Scope update:** the same six essential features as Phase 1, with nine screens instead of six, five statuses (`waiting`, `called`, `served`, `skipped`, `left`), and two notification triggers (2 customers ahead, and called).
- **Data design:** entities, fields, Dart types and data sources for `AppUser`, `ServiceQueue`, `QueueEntry` and `QueueNotification`, plus the planned Firestore collections (`users`, `queues`, `queues/{id}/entries`). Passwords stay in Firebase Authentication only.
- **Queue rules and waiting estimate:** one active membership per customer, one queue per provider, fixed ticket with changing position, and `estimated wait = customers ahead × average minutes`. The called customer counts as ahead. Worked examples are in the Phase 2 report.
- **State management plan:** Provider for shared state (`AuthProvider`, `QueueProvider`, `MembershipProvider`, `ProviderQueueProvider`) and `setState` for temporary screen state. Firestore synchronizes data between devices; Provider manages state inside each running app.
- **Notification plan:** push messages are sent by a Cloud Function, because Firebase Cloud Messaging does not send automatically when Firestore changes.
- **Navigation:** the provider flow is Dashboard → Create Queue → Queue Management, with tabs for Home / My Queue and Dashboard / Manage Queue.

### What the starter does today

The starter uses one `QueueDemoState` (a `ChangeNotifier`) created in `main.dart`, passed to each screen through its constructor, and rebuilt with `AnimatedBuilder`. It does not use the `provider` package yet. Nothing is saved after the app closes.

- **Sample data:** Campus Barber, 5 min average. #09 is called; #10, #11 and #12 are waiting. The demo customer (Noor Abdullah) holds #12, with 3 customers ahead and an estimate of 15 min.
- **Actions:** Join, Leave, Call Next, Mark as Served, Skip and Create Queue, each checking its rule before changing the data.
- **Trying Join:** the demo customer already holds a ticket, so Leave first. Joining again creates ticket #13, with 4 ahead and 20 min.
- **Sign-in:** Login and Register only check the form fields. No credentials are verified or stored. Registering always creates the demo user `customer-1` or `provider-1`.

**Known limits (planned for Phase 3):**

- The Near Turn and Called banners are computed from the customer's ticket and position. The notification objects in `QueueDemoState` are created but not displayed, and no push notification is sent.
- Create Queue is a preview, because the sample queue already exists.
- Loading, Joining, Error and Update Failure states exist only in the Figma designs.
- `isOpen` is a plain `bool`. The Dashboard "Open" label is fixed text.

## Run

Install Flutter, then run from the project folder:

```bash
flutter pub get
flutter analyze
flutter run
```

## Project structure

```text
lib/
  main.dart
  models/queue_data.dart
  screens/customer_screens.dart
  screens/provider_screens.dart
test/
  widget_test.dart
```

`main.dart` contains the app entry point, theme, named routes, and the Login, Register and Profile screens.

**Dependencies:** Flutter (interface), `cupertino_icons` (icons), `flutter_test` (tests), and `flutter_lints` (analysis). Planned for later: Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging, Cloud Functions, and `provider` for shared state. Only add packages to `pubspec.yaml` when used.

## Links

- [Figma designs](https://www.figma.com/design/sVVahJW10wMCvfVPgKibRQ/QueueLess-Phase-2?node-id=0-1)
- [Repository URL](https://github.com/Abdulrahim-Albijadi/SWE463-Group7-Project/tree/main)

## References, Licenses and AI Use

### References

1. [Flutter documentation](https://docs.flutter.dev)
2. [Provider package](https://pub.dev/packages/provider)
3. [Firebase Authentication](https://firebase.google.com/docs/auth)
4. [Cloud Firestore](https://firebase.google.com/docs/firestore)
5. [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
6. [Cloud Functions Firestore triggers](https://firebase.google.com/docs/functions/firestore-events)
7. [Figma](https://www.figma.com)

### Licenses

- Flutter: BSD 3-Clause
- provider package (planned): MIT
- Firebase documentation and services (planned): content CC BY 4.0; code samples Apache License 2.0
- Material Icons: Apache License 2.0
- Figma: Figma Terms of Service

### AI-use disclosure

The team made the design and product decisions and planned the data entities, state management, queue rules, and notifications. Figma AI and ChatGPT were used for some screen drafts, Flutter starter code examples, and suggestions. Claude was used to help structure the report and README and to correct grammar. The team reviewed, edited, integrated, and tested everything it submitted and is responsible for the submitted work.
