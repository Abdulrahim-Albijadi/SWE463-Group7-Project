# Customer Phase 4 Implementation and Testing

Owner: Bader Alshehri
Date: 22 November 2026
Branch: phase4/customer-ui
Starting revision: 241a7e1

## Changes

- Fixed the Home tab from Queue Details.
- Made system Back from Queue Details and My Queue return Home.
- Prevented delayed join completion from replacing another visible page.
- Guarded leave confirmation against account or ticket changes.
- Guarded late leave feedback after navigation or account changes.
- Displayed current position separately from the fixed ticket number.
- Adapted ticket numbers, status headings, and statistics for narrow layouts.
- Moved Open/Closed below the service description.
- Added descriptive screen-reader labels for ticket numbers and statistics.

## Environment

- Flutter 3.47.9 stable
- Dart 3.13.7
- Windows development machine
- Physical HONOR NTH NX9 running Android 13

## Automated Verification

| Check | Result |
| --- | --- |
| Formatting of all seven changed/new Dart files | Passed |
| flutter analyze | No issues found |
| flutter test | All 130 tests passed |

The suite increased from 121 to 130 tests.

Added coverage:
- Three customer navigation tests.
- Delayed join completion while another page is visible.
- Leave confirmation after a ticket is replaced.
- Current position display.
- My Queue at 280 logical pixels and 200% text.
- Customer Home and Queue Details at the same width and text scale.

Layout tests scroll through the content to check for rendering errors.
These widget tests use in-memory repositories, not live Firebase.

## Manual Verification on HONOR

| Check | Observed result |
| --- | --- |
| Build, install, and launch | Passed |
| Customer Home | Existing test queue displayed |
| Home tab from Queue Details | Returned to Home |
| System Back from Queue Details | Returned to Home |
| System Back from My Queue | Returned Home and kept the app open |
| Join test queue | Ticket #8 displayed as Waiting |
| Current position | Position 2, one customer ahead, five-minute estimate |
| Cancel Leave | Ticket #8 remained Waiting |
| Confirm Leave | Left state and confirmation message displayed |
| Rejoin | New ticket #9 displayed as Waiting, position 2 |
| Open ticket from Home | Returned to the same ticket #9 |
| Cleanup | Confirmed departure from ticket #9 |

The running Firebase-backed application was used for this single-device
customer flow. Existing records belonging to other customers were not
intentionally changed.

## Remaining Integration Checks

- Simultaneous Provider and Customer updates on the final merged version.
- Final backend concurrency guarantees.
- FCM permissions and foreground/background delivery.
- Controlled network failure and recovery.
- Physical TalkBack interaction.
- Final screenshots and commit/PR evidence for the report.

Delayed join navigation and replaced-ticket confirmation were verified
through automated tests; they were not manually reproduced across devices.

## AI Assistance

ChatGPT assisted with reviewing customer behavior, suggesting targeted
fixes, preparing regression tests, and drafting this record.
Bader applied the changes locally and ran the recorded checks.
The team remains responsible for reviewing and understanding submitted code.