# QueueLess

**SWE 463 — Group 7 | Phase 2**

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
```

**Dependencies:** Flutter (interface), `cupertino_icons` (icons), `flutter_test` (tests), and `flutter_lints` (analysis). Planned for later: Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging, and `provider` for shared state. Only add packages to `pubspec.yaml` when used.

## Links

- [Figma designs](https://www.figma.com/design/sVVahJW10wMCvfVPgKibRQ/QueueLess-Phase-2?node-id=0-1)
- [Repository URL](https://github.com/Abdulrahim-Albijadi/SWE463-Group7-Project/tree/main)

## References and AI use

Design guidance: [Flutter](https://docs.flutter.dev/), [Material 3](https://m3.material.io/), and [Firebase](https://firebase.google.com/docs). List sources and licenses for any additional external assets or code used.

**AI assistance:** Figma AI and ChatGPT were used for some screen drafts, Flutter starter code examples, and suggestions. The team is responsible for reviewing, integrating, and testing the submitted work.