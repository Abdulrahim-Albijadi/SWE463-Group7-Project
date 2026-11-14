# Provider testing and verification

**Date:** 14 November 2026 (Asia/Riyadh)  
**Branch:** `omar`  
**Base revision:** `7872f7064f863206c65c72abbf9e77fb9b9cac53`  
**Scope:** Uncommitted Provider screen separation, followed by documentation and evidence organization.

The base matches `origin/main` and the remote `main` head checked with `git ls-remote`. It includes the team's Provider queue loading/stream recovery fix (`026f435`), authentication profile-listener fix (`f7a6b4d`), and customer smoke-test setup fix (`29061d4`). Shared Providers, repositories, rules, models, Customer screens/widgets, tests, route definitions, Firebase configuration, and dependency files are unchanged by this cleanup.

## Resulting organization

```text
lib/screens/provider/
  provider_dashboard_screen.dart
  create_queue_screen.dart
  queue_management_screen.dart
lib/screens/provider_screens.dart        compatibility exports
lib/widgets/provider/provider_widgets.dart
test/
  provider_screens_test.dart
  provider_queue_loading_test.dart
  provider_evidence_test.dart
docs/
  README.md
  provider_report.md
  provider_testing.md
  evidence/
    provider_screenshots_manifest.json
    provider_screenshots/
    logs/
```

The screen bodies were compared with the base revision after accounting for imports, formatting, and extracted UI references. UI text, styling, guards, async operations, state handling, and navigation remain equivalent. Queue-count formatting accepts the existing derived count and called-customer flag; queue rules remain in the shared state/logic layers.

## Checks

| Command/check | Result | Evidence |
| --- | --- | --- |
| `flutter pub get` | PASS; dependency files unchanged | [Log](evidence/logs/cleanup-2026-11-14-pub-get.txt) |
| `dart format` on all five changed/new Dart files | PASS | [Log](evidence/logs/cleanup-2026-11-14-format.txt) |
| `flutter analyze` | PASS; no issues | [Log](evidence/logs/cleanup-2026-11-14-analyze.txt) |
| `flutter test --reporter expanded` | PASS; all 78 tests, no failures | [Log](evidence/logs/cleanup-2026-11-14-test.txt) |
| `flutter build web` | PASS; generated `build/web` | [Log](evidence/logs/cleanup-2026-11-14-build-web.txt) |
| Original screenshot manifest | PASS; all 41 files present with matching SHA-256 hashes | [Manifest](evidence/provider_screenshots_manifest.json) |
| Local documentation links and `git diff --check` | PASS | Evidence index and report references resolve within the relocated structure |

The existing Provider UI suite covers loading/error/retry and empty states, validation, busy/duplicate-submit guards, action success/failure, delayed snapshots, Customer membership updates, disposal, narrow layouts, keyboard scrolling, and application routes. The team's stream recovery regression tests ran as part of the full suite. No unrelated tests failed.

## Evidence preservation and limits

Documentation is now in `docs/provider_report.md` and `docs/provider_testing.md`, with the documentation index in `docs/README.md`. Screenshots and logs are in `docs/evidence/`, and the capture harness is in `test/provider_evidence_test.dart`. Every moved file was verified against its original SHA-256 hash before documentation edits or removal of the empty source directory. Historical `.log` files remain explicitly allowed by `.gitignore` at their new location. All original screenshots, logs, and Firebase verification records retain their contents. New logs use separate dated names.

Earlier organization checks did not rerun the mock capture harness. It now runs its workflow assertions with the normal test suite; screenshot generation requires an explicit flag and writes only to `build/provider_screenshots/`. Archived captures are preserved. This verification used local automated tests and a local web build; no new live Firebase testing or deployment occurred. Original `live-*` captures retain their original scope and date, and `mock-*` captures remain labeled as local UI evidence.

No refactor issues remain. Existing feature limitations documented in the project README remain outside this cleanup. Six newer dependency versions were reported by `flutter pub get`; dependency constraints and resolved versions were retained.

No commits, pushes, merges, branch switches, resets, rebases, deployments, or Firebase modifications were performed.

## Documentation relocation checks — 14 November 2026

Repository inspection found shared team documentation in the root README and automated tests in `test/`. No separate reports or evidence directories for other team members were found in the working tree or the locally available remote branch trees. The final layout uses the shared `docs/` directory for reports and `docs/evidence/` for captures and logs, leaving other members' work in place.

During the preceding documentation cleanup, all 67 files present at its start were accounted for. Its 41 screenshots and 21 historical log/JSON records remained byte-for-byte unchanged. Only the three Markdown documents, capture harness paths, and manifest location metadata needed content updates. No evidence was discarded or regenerated, and the empty source directory was removed after hash verification. Any original command paths inside historical logs remain part of the archived record.

The report now has a feature-based filename and a Contribution section containing the contributor's name and student ID. Root README references, relative links back to `lib/` and `test/`, manifest metadata, capture commands, and the six existing log-ignore exceptions all use the new directory.

| Check | Result | Evidence |
| --- | --- | --- |
| Local Markdown links and JSON evidence references | PASS; all current references resolve | [Link and preservation checks](evidence/logs/documentation-2026-11-14-links.txt) |
| Screenshot manifest | PASS; all 41 capture hashes and dimensions match | [Manifest](evidence/provider_screenshots_manifest.json) |
| Protected file comparison | PASS; all 166 application, test, platform, dependency, and Firebase files match the start of this documentation cleanup | [Preservation checks](evidence/logs/documentation-2026-11-14-links.txt) |
| `flutter analyze` | PASS; no issues | [Analysis log](evidence/logs/documentation-2026-11-14-analyze.txt) |
| `git diff --check`, branch, and HEAD | PASS; branch remains `omar` and HEAD is unchanged | [Checks](evidence/logs/documentation-2026-11-14-links.txt) |

The earlier screen refactor and its test/build results remain as recorded above. This documentation-only follow-up did not rerun the screenshot capture harness, contact Firebase, change application code, or perform any Git publishing operation.

## Unified application organization

Reports and supporting documentation now live directly in `docs/`. All Provider tests are in the existing flat `test/` directory. Provider screenshots use `docs/evidence/provider_screenshots/`; original test logs and Firebase records remain grouped under `docs/evidence/logs/`. No phase-specific or personal directories remain in the current documentation layout.

The 69 documentation, test-harness, manifest, screenshot, and log files present at the start of this final cleanup were mapped to their new locations and hash-checked before editing documentation. All 41 screenshots and 23 existing log/JSON records retain their exact bytes. Earlier test failures remain visible in the historical logs; later passing runs are stored separately. Repeated capture contents are retained because their filenames identify distinct verification checkpoints. Empty source directories were removed after file preservation was confirmed.

Application source, existing regression tests, Firebase configuration, shared Providers, repositories, authentication, dependencies, and platform files were compared with the start of this final cleanup. They were not modified. No commits, pushes, merges, resets, rebases, branch switches, deployments, or Firebase changes were made.

The moved capture harness retains its original three workflow scenarios. Ordinary `flutter test` runs execute their assertions without writing images or requiring SDK capture fonts. Explicit capture uses the command in the [documentation index](README.md) and writes fresh mock images to `build/provider_screenshots/`. These generated images are separate from the archived live and mock evidence.

| Final verification | Result | Record |
| --- | --- | --- |
| File accounting | PASS; all 69 original files accounted for, including 41 screenshots and 23 unchanged archived logs/JSON records | [File inventory](evidence/provider_file_inventory.json) |
| Documentation and evidence links | PASS; local Markdown links and JSON evidence references resolve | [Organization checks](evidence/logs/repository-organization-checks.txt) |
| `flutter analyze` | PASS; no issues | [Analysis log](evidence/logs/repository-organization-analyze.txt) |
| `flutter test --reporter expanded` | PASS; all 81 tests, including the three relocated workflow tests | [Full test log](evidence/logs/repository-organization-tests.txt) |
| Opt-in screenshot harness | PASS; all three tests and 19 new mock captures in ignored build output | [Capture test log](evidence/logs/provider-screenshot-capture-test.txt) |
| Archived captures and protected application/team files | PASS; all original screenshot hashes, source labels and dimensions match; all 166 protected files unchanged | [Preservation checks](evidence/logs/repository-organization-checks.txt) |
| Final layout and `git diff --check` | PASS; no duplicate, obsolete, empty, phase-specific or personal documentation directories; clean diff checks | [Organization checks](evidence/logs/repository-organization-checks.txt) |

No unrelated tests failed. Existing product limitations in the project README remain outside this organization cleanup. No new live Firebase verification was performed.
