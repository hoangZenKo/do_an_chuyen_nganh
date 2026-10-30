# System Demo Implementation Plan

**Goal:** Run a slow, visible, role-switching system demo on a dedicated iOS simulator, with an explicit coverage report rather than a misleading all-green claim.

**Architecture:** One commented JavaScript scenario entry point drives a test-only Flutter entry point through Appium. A disposable local PostgreSQL database and separate backend isolate all test mutations. Screen checks, UI journeys, and existing automated business-rule tests are reported separately.

**Tech Stack:** Flutter Driver extension (debug only), Appium Flutter/XCUITest, Node.js test runner, existing Jest/Flutter tests.

## Constraints
- Do not change production behavior or reuse personal accounts, database rows, uploads, or external delivery providers.
- Default delay 2 seconds per action; numbered Vietnamese scenario comments and captions.
- Discover route and automated-suite inventories from source; unverified actions remain explicit coverage gaps.
- Never count screen navigation as business-operation coverage; failed or blocked tests stay failed/blocked.
- Do not commit, delete existing data, or revert unrelated working-tree changes.

## Tasks
- [x] Add tested configuration, route inventory, report generation and safety guards.
- [x] Add isolated fixture/backend orchestration and test-only driver entry point.
- [x] Implement numbered role-switching UI sections and a route inventory sweep.
- [x] Integrate existing Flutter/backend suites without weakening their safety guards.
- [x] Validate helpers, analyze Dart, launch on simulator and report actual results/remaining gaps.

## Verification
- Helper tests: 11 passed; Dart analyze clean; Dart format unchanged.
- Dedicated simulator exercised business journeys and 82 route smoke checks.
- Regression: Flutter 782 passed/1 failed; backend unit 746 passed/7 skipped;
  API E2E 263 passed/6 failed across 36 suites; script safety tests 19 passed.
- Invoice cancellation and support retain runtime failures; no production fixes
  were folded into this automation task. See the demo README for reports/gaps.
- Earlier cleanup EPERM reports were recovered and exact test databases removed.
  Latest login smoke passed all four roles, generated its report, exited 0,
  removed its disposable database and left no owned API/Appium processes.
- No full green end-to-end run or exhaustive UI-function coverage is claimed.

## Review Focus
- Invalid/remote database URLs must fail before any SQL or application launch.
- Missing routes, fixtures, selectors and environmental dependencies must never become passes.
- Capture screenshots, steps, assertion errors and machine-readable results on failure.
- Do not leak passwords/tokens in screenshots, logs, manifests or versioned files.
- Stop only owned processes and clean up only an exact generated database name.
