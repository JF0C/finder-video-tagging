# Video Tagging

This macOS service assigns Finder tags to `.mkv`, `.mp4`, `.mov`, and `.m4v` files.

- New videos are tagged `New`.
- Playing videos are tagged `Watching`.
- Videos that meet the selected completion criterion are tagged `Viewed`.

## Setup

Run the setup script from this repository:

```sh
chmod +x setup.sh
./setup.sh
```

During setup:

- Choose the folders to observe.
- Select one or both `Viewed` criteria: percentage watched and seconds before the end.
- Optionally enable playback resumption after AirPods are removed. Choose the AirPlay output
	(such as an Apple TV) and the AirPods/Bluetooth output from the devices currently available
	to macOS, then choose how many seconds to rewind.
- Rerun `./setup.sh` to change these settings or apply source changes.

macOS requests Automation permission for VLC and QuickTime Player on the first playback check. Approve it in System Settings > Privacy & Security > Automation.

When playback resumption is enabled, the service records VLC and QuickTime media playing as
audio changes from the selected AirPlay output to the selected Bluetooth output. When audio then
leaves that Bluetooth output, it restores the selected AirPlay output, rewinds the same paused
media, and resumes it. The output-device switch is system-wide, so other apps using the default
macOS output move too; no other app is paused, sought, or resumed.

## Uninstall

Run the uninstaller from the same macOS account used for setup:

```sh
chmod +x uninstall.sh
./uninstall.sh
```

This removes the LaunchAgent, configuration, and logs, but leaves the repository and build artifacts.

## Development

The Swift package keeps the `VideoTagging` and `FolderPicker` executables as thin entry points.
Reusable behavior lives in `VideoTaggingCore` and `FolderPickerCore`, organized by feature. Tests
mirror those feature folders under `Tests/VideoTaggingCoreTests` and `Tests/FolderPickerCoreTests`.

Install the optional Git hooks after cloning:

```sh
brew install pre-commit
pre-commit install
```

The repository uses only local hooks, so `pre-commit` is the sole additional package. Fast file
length, formatting, and coverage-guard contract checks run before commits. The full test and
coverage gate runs before pushes.

Run the same quality checks used by pull-request CI:

```sh
Scripts/check-file-lengths.sh
swift format lint --recursive --strict Sources Tests Scripts/CoverageGuard.swift Package.swift
swift build
Scripts/test-coverage-guard.sh
Scripts/check-coverage.sh
```

Run installed hook stages manually with:

```sh
pre-commit run --all-files
pre-commit run --hook-stage pre-push --all-files
```

Tests use XCTest and isolate macOS integrations, so they do not require VLC, QuickTime, audio
hardware, Finder access, or Automation permission. A full Xcode installation is required to run
XCTest on macOS; standalone Command Line Tools may compile the package without providing XCTest.

The coverage guard uses SwiftPM, Xcode's `llvm-cov`, and the Git diff against `origin/main` (or
`COVERAGE_BASE_REF`). It requires at least 90% line coverage across testable production code and 95%
coverage on executable lines added or edited relative to the base ref. Explicit exclusions are kept
in `Scripts/coverage-exclusions.txt`; they cover generated, test, and resource paths plus thin macOS
adapters that require UI, hardware, applications, or system permissions. Override the thresholds
locally with `COVERAGE_OVERALL_MINIMUM` and `COVERAGE_CHANGED_MINIMUM` when testing the guard itself.

See `AGENTS.md` for architecture, behavioral invariants, and contribution conventions. Swift source
and test files are limited to 200 physical lines, which is enforced in CI.
