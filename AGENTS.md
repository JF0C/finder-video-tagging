# Video Tagging Agent Guide

## Project Purpose

Video Tagging is a macOS 15 service written in Swift 6.2. It watches selected folders and applies
Finder tags to supported video files. New files receive `New`, active playback receives `Watching`,
and videos that satisfy a configured completion rule receive `Viewed`. An optional workflow restores
an AirPlay output and resumes VLC or QuickTime playback after Bluetooth headphones disconnect.

The `FolderPicker` executable collects configuration. The `VideoTagging` executable runs as a user
LaunchAgent. Keep both executable names and their command-line behavior stable because `setup.sh`
depends on them.

## Architecture

- Keep executable targets as thin composition roots.
- Put reusable behavior in importable core targets so it can be unit tested.
- Separate deterministic policy from AppKit, CoreAudio, FSEvents, AppleScript, extended attributes,
  timers, and the real file system.
- Group source and tests into feature folders such as `Configuration`, `Tagging`, `Watching`,
  `Playback`, `Audio`, and `UI`.
- Mirror source feature folders under the corresponding SwiftPM test target.

## Code Structure

- Every Swift source and test file must contain at most 200 physical lines.
- Prefer one primary class, struct, enum, or protocol per file.
- Split by class or cohesive responsibility before a file approaches the limit.
- Create a feature or component subfolder when files share a distinct responsibility. Avoid both a
  large flat directory and folders that contain only arbitrary fragments.
- Keep names aligned with behavior and use the existing Swift formatting style.
- Do not add dependencies when the standard library or macOS frameworks already provide a clear
  solution.

## Behavioral Invariants

- Supported extensions are `mkv`, `mp4`, `mov`, and `m4v`, matched case-insensitively.
- Preserve Finder tags that are not managed by this service.
- Never replace an existing managed tag when applying `New` with `onlyIfUnmanaged`.
- A video is `Viewed` when either enabled completion criterion is satisfied.
- Only playback inside an observed folder may change tags.
- Playback resumption must affect only the exact VLC or QuickTime items captured during the output
  transition, and rewind time must never become negative.
- Unit tests and CI must not require VLC, QuickTime, audio hardware, Automation permission, or a
  logged-in Finder session.

## Testing

- Use XCTest so the suite runs with both Xcode and standalone Command Line Tools.
- Add or update tests with every behavior change. Cover success, failure, boundary, and state
  transition paths.
- Maintain at least 90% line coverage across testable production code and 95% coverage on executable
  lines added or edited in a pull request.
- Keep coverage exclusions narrow and explicit in `Scripts/coverage-exclusions.txt`. Exclude only
  generated, test, or resource files and thin platform adapters that cannot run deterministically in
  CI; do not exclude business or policy logic.
- Inject platform operations through protocols or closures. Prefer small fakes over global state.
- Keep platform adapters thin. Validate them through compilation and deterministic contract tests.

## Validation

Install the repository hooks with `pre-commit install` when `pre-commit` is available. Commit-time
hooks run fast static checks; the pre-push hook runs the complete test and coverage gate.

Run these commands before finishing a change:

```sh
Scripts/check-file-lengths.sh
swift format lint --recursive --strict Sources Tests Scripts/CoverageGuard.swift Package.swift
swift build
Scripts/test-coverage-guard.sh
Scripts/check-coverage.sh
```

For changes affecting packaging or setup, also run `swift build -c release` and confirm
`.build/release/VideoTagging`, `.build/release/FolderPicker`, and
`.build/release/BrowserNativeBridge` still exist. Do not run the folder picker in unattended
automation because it opens a modal UI.

## Change Discipline

- Keep changes focused and preserve existing user-visible behavior unless the request says otherwise.
- Document and read implementation plans in the relevant GitHub issue; do not commit planning
  documents to this repository.
- Do not edit generated files under `.build`.
- Do not commit user configuration, logs, or machine-specific paths.
- Work with existing uncommitted changes and never discard them without explicit approval.
- Update `README.md` when setup, behavior, architecture, or developer commands change.