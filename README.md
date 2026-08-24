# Video Tagging

This macOS service assigns Finder tags to `.mkv`, `.mp4`, `.mov`, and `.m4v` files.

- New supported files created in or moved into `/Users/jan/Downloads` or `/Users/jan/Movies` are tagged `New` after their size remains unchanged for two seconds, but only if none of `New`, `Watching`, or `Viewed` is already assigned. Folders moved into either location are scanned recursively.
- Only files within the observed Downloads and Movies folders can receive playback state tags. Files actively played in VLC or QuickTime Player are tagged `Watching` until playback reaches 85%.
- Files at 85% or more of their duration are tagged `Viewed`. This is based on the current playback position, so seeking to 85% also marks a file `Viewed`; cumulative watch time is not tracked.
- State transitions remove the prior state tag: `New` to `Watching` or `Viewed`, `Watching` to `Viewed`, and `Viewed` to `Watching` when replay begins below the 85% threshold.
- Managed tags include Finder colors: `New` is blue and `Watching` is yellow. `Viewed` has no Finder color badge.
- Any unrelated Finder tags, including their colors, are preserved. One second after every managed state update, the service removes the German and English blue/green/yellow color-name tags (`Blau`, `Grün`, `Gelb`, `Green`, `Yellow`) to prevent duplicate state indicators.

## Setup

Run the setup script from this repository:

```sh
chmod +x setup.sh
./setup.sh
```

Setup detects the current macOS user and starts with Downloads and Movies selected. The installer shows the selected locations in a list. Use the plus button to add folders and select a folder to enable the minus button, which removes it. It writes the selected paths to `~/Library/Application Support/VideoTagging/config.json`, builds the executable, and installs a per-user LaunchAgent.

Rerun `./setup.sh` to change the observed folders. The LaunchAgent starts automatically when you log in after boot and restarts the service if it exits. Logs are written to `~/Library/Logs/video-tagging.log` and `~/Library/Logs/video-tagging-error.log`.

On its first playback check, macOS requests Automation permission to control VLC and QuickTime Player. Approve both in System Settings > Privacy & Security > Automation.

## Uninstall

Run the uninstaller from the same macOS account used for setup:

```sh
chmod +x uninstall.sh
./uninstall.sh
```

This stops and removes the current and legacy LaunchAgents, configuration, and service logs. It leaves this repository and its build artifacts in place.
