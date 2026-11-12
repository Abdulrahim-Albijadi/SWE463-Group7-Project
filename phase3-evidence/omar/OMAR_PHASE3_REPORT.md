# QueueLess — Omar's Phase 3 Implementation and Verification

**Name:** Omar Alshehri  
**Student ID:** 202177130  
**Assigned responsibility:** Provider Screens and Queue Management  
**Verification date:** 12 November 2026 (Asia/Riyadh)  
**Branch / tested revision:** `omar` / `b2ed8af4692ddfe312033ca9d0eb3837820abdc1`  
**GitHub contribution:** [PR #9](https://github.com/Abdulrahim-Albijadi/SWE463-Group7-Project/pull/9), [commit b2ed8af](https://github.com/Abdulrahim-Albijadi/SWE463-Group7-Project/commit/b2ed8af4692ddfe312033ca9d0eb3837820abdc1). Commit verified locally; PR status not checked.

## Implemented features

- Provider Dashboard: empty, active, loading and error states; service details, waiting/active counts, called customer and Retry.
- Create Queue: required name/description, positive integer duration, progress, success/error feedback, retry, duplicate-submit protection and existing-queue prevention.
- Queue Management: ordered waiting list, fixed ticket numbers, joining times, Call Next, Mark as Served, Skip and failed-update retry. Serving/skipping does not automatically call another customer.
- Existing Providers and Firebase repositories supply data and operations. Controls prevent conflicting writes and await stream updates. The approved teal Material 3 styling supports scrolling, keyboards and narrow layouts.

## Live Firebase verification — PASSED

The **actual Flutter application** ran in Chrome at `http://localhost:8765` with the existing `queueless-group7` configuration. Two new accounts were registered through the app; Firebase Authentication returned HTTP 200 for both sign-ups. Provider and Customer then used independent Chrome profiles. Queue operations and sign-ins used the existing Firebase-backed repositories through the UI.

| Test | Expected result | Actual result |
| --- | --- | --- |
| Register Provider and Customer | Create two isolated accounts with the selected roles | **PASS**; Provider reached Dashboard, Customer reached Customer Home; Customer profile confirms its role. |
| Create Campus Barber | Save one queue with five-minute service duration | **PASS**; creation succeeded; both sessions displayed Campus Barber and five minutes. |
| Restart Provider application | Queue survives a new Flutter runtime | **PASS**; full browser reload, then sign-in, recovered the queue and service duration. |
| Customer joins | Ticket appears in Customer and Provider sessions | **PASS**; Customer received #1; Provider displayed the new customer without refreshing. |
| Call Next | Customer becomes called; another call is blocked | **PASS**; Customer displayed “It’s your turn!” automatically; Provider's Call Next was disabled. |
| Mark as Served | Customer receives served status; nobody is auto-called | **PASS**; #1 became Served in both sessions. Customer still showed Served after a reload and sign-in. |
| Rejoin and Skip | New fixed ticket; skipped status reaches Customer | **PASS**; the same new Customer rejoined as #2, was called, then skipped. Both sessions updated without refreshing. |
| Final persistence | Queue and latest customer status survive both restarts | **PASS**; after full browser reloads and sign-ins, Provider retained Campus Barber at five minutes with no active customers; Customer retained Skipped #2. |

**Restart method:** full document reloads reinitialized Flutter and its Providers, followed by explicit sign-in using the new test accounts. Automatic restoration directly into the signed-in screen was not claimed. Real-time checks above occurred before those reloads.

### Isolated records used

- Provider: `queueless.phase3.omar.provider.889fd60618e@example.com`
- Customer: `queueless.phase3.omar.customer.889fd60618e@example.com`
- Queue document: `queues/dbIZuVG1rDTe3sGaUCHSwaUzmnz2`
- Queue description: `Isolated Phase 3 test - Omar 202177130 - 889fd60618e`
- Test outcomes: ticket #1 Served; ticket #2 Skipped. The new test accounts and records were retained; existing records were not modified. Passwords and tokens are excluded from the evidence package.

Audit evidence: [live workflow summary](logs/live-workflow.json), [Provider registration](logs/live-provider-registration.json), [Customer registration](logs/live-customer-registration.json), [queue creation](logs/live-queue-creation.json), [Customer visibility](logs/live-customer-queue-visibility.json), [join/call/serve/persistence](logs/live-actions-and-persistence.json), [Skip and final restart](logs/live-skip-and-restart.json), [final UI checkpoint](logs/live-final-checkpoint.json).

## Genuine live screenshots

These `live-*.png` images capture the actual application connected to Firebase. The earlier `mock-*.png` images remain separately labeled as local UI evidence and were **not used** to establish the live results.

| Evidence | Files |
| --- | --- |
| New accounts | [Provider registration](screenshots/live-provider-registration-form.png), [Provider Dashboard after registration](screenshots/live-provider-registration-result.png), [Customer registration](screenshots/live-customer-registration-form.png), [Customer profile](screenshots/live-customer-profile.png) |
| Create Queue | [Five-minute form](screenshots/live-create-queue-form.png), [successful creation](screenshots/live-queue-created.png) |
| Customer visibility / join | [New queue visible to Customer](screenshots/live-customer-sees-queue.png), [queue details](screenshots/live-customer-queue-details.png), [Provider waiting list](screenshots/live-provider-waiting-list.png) |
| Call Next | [Provider Called](screenshots/live-provider-called.png), [Customer Called](screenshots/live-customer-called.png) |
| Served | [Provider Served](screenshots/live-provider-served.png), [Customer Served](screenshots/live-customer-served.png) |
| Skip | [Provider Skipped](screenshots/live-provider-skipped.png), [Customer Skipped](screenshots/live-customer-skipped.png) |
| Persistence | [Provider after restart](screenshots/live-provider-final-persistence.png), [Customer Skipped after restart](screenshots/live-customer-skipped-after-restart.png) |

The [screenshot manifest](screenshots-manifest.json) lists every file's source, dimensions and SHA-256 hash.

## Automated verification and remaining issues

The earlier automated checks cover the same unchanged implementation:

| Check | Result |
| --- | --- |
| `flutter pub get` | **PASS**; constraints unchanged. [Log](logs/flutter-pub-get.log) |
| `flutter analyze` | **PASS**, no issues. [Log](logs/flutter-analyze.log) |
| `flutter test` | **68 passed, 1 failed overall**; all 27 Provider UI tests passed. [Log](logs/flutter-test.log) |
| Separate mock screenshot harness | **3 passed**; local UI captures only. [Log](logs/mock-evidence-tests.log) |

Validation, duplicate-queue prevention, simulated loading/error/retry states, delayed snapshots, disposal, 280px layouts and keyboard scrolling were verified in local tests. Failure injection and those edge cases were not repeated against live Firebase in this run.

Teammate follow-up remains:

1. [Customer smoke test](../../test/widget_test.dart) line 10 omits `AppProviders`, causing `ProviderNotFoundException<MembershipProvider>`. Wrap the app with the existing Providers and test repositories.
2. [ProviderQueueProvider](../../lib/providers/provider_queue_provider.dart) reports ready before its first entries snapshot and does not automatically clear an entry-stream error on recovery. Shared readiness/error handling remains unchanged; explicit Retry is covered locally.

There is no remaining blocker for the requested live Provider/Customer acceptance flow. Firebase configuration, security rules, shared code and teammate files were not changed. No commit, push, merge or deployment occurred.

## Provider workflow for the team report

Provider signs in → Dashboard → Create Queue with name, description and duration → Queue Management. Customers join and appear in order. Call Next calls the first waiting customer and blocks another call until Served or Skip. These actions update the Customer session in real time without automatically calling another customer. Live testing confirmed queue persistence and terminal ticket status after application reloads and sign-in.
