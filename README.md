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
- Rerun `./setup.sh` to change these settings or apply source changes.

macOS requests Automation permission for VLC and QuickTime Player on the first playback check. Approve it in System Settings > Privacy & Security > Automation.

## Uninstall

Run the uninstaller from the same macOS account used for setup:

```sh
chmod +x uninstall.sh
./uninstall.sh
```

This removes the LaunchAgent, configuration, and logs, but leaves the repository and build artifacts.
