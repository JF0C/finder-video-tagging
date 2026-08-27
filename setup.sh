#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
label="com.video-tagging"
legacy_label="com.jan.video-tagging"
console_user=$(/usr/bin/stat -f %Su /dev/console)

if [[ "$console_user" == "root" || "$console_user" != "$(id -un)" ]]; then
    print -u2 "Run setup from the logged-in macOS user account."
    exit 1
fi

home_directory=$(dscl . -read "/Users/$console_user" NFSHomeDirectory | awk '{print $2}')
config_directory="$home_directory/Library/Application Support/VideoTagging"
config_file="$config_directory/config.json"
agent_file="$home_directory/Library/LaunchAgents/$label.plist"
host_name="com.findervideotagging.browser"
chrome_host_directory="$home_directory/Library/Application Support/Google/Chrome/NativeMessagingHosts"
firefox_host_directory="$home_directory/Library/Application Support/Mozilla/NativeMessagingHosts"
extension_directory="$config_directory/BrowserExtension"
safari_group_directory="$home_directory/Library/Group Containers/group.com.findervideotagging.shared"

configuration=$(swift run -c release --package-path "$project_dir" FolderPicker)

if [[ -z "$configuration" ]]; then
    print -u2 "Setup cancelled."
    exit 1
fi

mkdir -p "$config_directory" "$home_directory/Library/LaunchAgents"
chmod 700 "$config_directory"

print -r -- "$configuration" > "$config_file"
chmod 600 "$config_file"

swift build -c release --package-path "$project_dir"

browser_resume_enabled=$(plutil -extract browserPlaybackResumeEnabled raw "$config_file" 2>/dev/null || print false)
if [[ "$browser_resume_enabled" == "true" ]]; then
    rm -rf "$extension_directory"
    mkdir -p "$extension_directory/chrome" "$extension_directory/firefox"
    cp -R "$project_dir/BrowserExtension/shared/." "$extension_directory/chrome"
    cp -R "$project_dir/BrowserExtension/shared/." "$extension_directory/firefox"
    cp "$project_dir/BrowserExtension/chrome/manifest.json" "$extension_directory/chrome"
    cp "$project_dir/BrowserExtension/firefox/manifest.json" "$extension_directory/firefox"
    mkdir -p "$chrome_host_directory" "$firefox_host_directory"
    mkdir -p "$safari_group_directory"
    chmod 700 "$safari_group_directory"

    cat > "$chrome_host_directory/$host_name.json" <<JSON
{
  "name": "$host_name",
  "description": "Finder Video Tagging browser bridge",
  "path": "$project_dir/.build/release/BrowserNativeBridge",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://lpmgamkmefpbdjbapjmgeldffhkpikmf/"]
}
JSON
    cat > "$firefox_host_directory/$host_name.json" <<JSON
{
  "name": "$host_name",
  "description": "Finder Video Tagging browser bridge",
  "path": "$project_dir/.build/release/BrowserNativeBridge",
  "type": "stdio",
  "allowed_extensions": ["browser@finder-video-tagging.local"]
}
JSON
    chmod 600 \
        "$chrome_host_directory/$host_name.json" \
        "$firefox_host_directory/$host_name.json"
else
    rm -rf "$extension_directory"
    rm -f \
        "$chrome_host_directory/$host_name.json" \
        "$firefox_host_directory/$host_name.json"
fi

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
if [[ "$browser_resume_enabled" == "true" ]]; then
    print "Load unpacked browser extensions from $extension_directory."
fi
