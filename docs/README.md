# QueueLess documentation

QueueLess is one Flutter application. The repository root README contains shared setup, feature, and team information. Supporting Provider documentation lives here; Flutter tests remain in the existing flat `test/` directory.

| Record | Location |
| --- | --- |
| Provider implementation and academic contribution | [provider_report.md](provider_report.md) |
| Provider testing and verification history | [provider_testing.md](provider_testing.md) |
| Archived capture metadata and SHA-256 hashes | [provider_screenshots_manifest.json](evidence/provider_screenshots_manifest.json) |
| File relocation and preservation inventory | [provider_file_inventory.json](evidence/provider_file_inventory.json) |
| Original live Firebase workflow | [live-workflow.json](evidence/logs/live-workflow.json) |
| Archived screenshots | [provider_screenshots/](evidence/provider_screenshots/) |
| Historical test logs and Firebase records | [logs/](evidence/logs/) |
| Provider UI and route tests | [provider_screens_test.dart](../test/provider_screens_test.dart) |
| Queue loading and recovery tests | [provider_queue_loading_test.dart](../test/provider_queue_loading_test.dart) |
| Provider workflow and optional mock captures | [provider_evidence_test.dart](../test/provider_evidence_test.dart) |

Screens remain in [lib/screens/provider/](../lib/screens/provider/), with reusable UI in [lib/widgets/provider/](../lib/widgets/provider/). Other team members' files were not reorganized.

Files named `live-*.png` are archived captures from the original Firebase verification session. Files named `mock-*.png` are local UI captures using test repositories and do not establish live Firebase results. The manifest retains their sources, original dates, dimensions, and hashes. Historical logs retain their original command text and capture values.

Run `flutter test` from the repository root to include all Provider regression tests. Screenshot generation is optional:

```bash
flutter test test/provider_evidence_test.dart --dart-define=CAPTURE_PROVIDER_SCREENSHOTS=true --reporter expanded
```

New mock captures are written to the ignored `build/provider_screenshots/` directory. Routine tests leave archived screenshots and verification records unchanged.
