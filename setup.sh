#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
label="com.video-tagging"
legacy_label="com.jan.video-tagging"
console_user=$(stat -f %Su /dev/console)

if [[ "$console_user" == "root" || "$console_user" != "$(id -un)" ]]; then
    print -u2 "Run setup from the logged-in macOS user account."
    exit 1
fi

home_directory=$(dscl . -read "/Users/$console_user" NFSHomeDirectory | awk '{print $2}')
config_directory="$home_directory/Library/Application Support/VideoTagging"
config_file="$config_directory/config.json"
agent_file="$home_directory/Library/LaunchAgents/$label.plist"

configuration=$(swift run -c release --package-path "$project_dir" FolderPicker)

if [[ -z "$configuration" ]]; then
    print -u2 "Setup cancelled."
    exit 1
fi

mkdir -p "$config_directory" "$home_directory/Library/LaunchAgents"

print -r -- "$configuration" > "$config_file"

swift build -c release --package-path "$project_dir"

cat > "$agent_file" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$project_dir/.build/release/VideoTagging</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$home_directory/Library/Logs/video-tagging.log</string>
    <key>StandardErrorPath</key>
    <string>$home_directory/Library/Logs/video-tagging-error.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$legacy_label" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent_file"

print "Video Tagging setup is complete."
