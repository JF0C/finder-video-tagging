# Video Tagging

This macOS service assigns Finder tags to `.mkv`, `.mp4`, `.mov`, and `.m4v` files.

- New files added to an observed folder are tagged `New` after their size is stable for two seconds. Moved folders are scanned recursively.
- Videos playing in VLC or QuickTime Player are tagged `Watching`, then `Viewed` at 85% progress. Seeking also changes the tag; cumulative watch time is not tracked.
- `New`, `Watching`, and `Viewed` replace one another and use Finder blue, yellow, and gray colors. Unrelated Finder tags are preserved.

## Setup

Run the setup script from this repository:

```sh
chmod +x setup.sh
./setup.sh
```

Setup starts with Downloads and Movies selected. Add or remove observed folders in the picker, then continue. It writes the selected paths to `~/Library/Application Support/VideoTagging/config.json`, builds the executable, and installs a per-user LaunchAgent.

Rerun `./setup.sh` to change observed folders or apply changes made to the source code. It rebuilds and reloads the service. The service starts at login, restarts if it exits, and logs to `~/Library/Logs/video-tagging.log` and `~/Library/Logs/video-tagging-error.log`.

macOS requests Automation permission for VLC and QuickTime Player on the first playback check. Approve it in System Settings > Privacy & Security > Automation.

## Uninstall

Run the uninstaller from the same macOS account used for setup:

```sh
chmod +x uninstall.sh
./uninstall.sh
```

This removes the LaunchAgent, configuration, and logs, but leaves the repository and build artifacts.
