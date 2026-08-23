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

selected=$(osascript <<'APPLESCRIPT'
set observedFolders to {POSIX path of (path to downloads folder), POSIX path of (path to movies folder)}

repeat
    set action to button returned of (display dialog "Choose folders for automatic video tagging." buttons {"Cancel", "Remove Folders...", "Add Folders...", "Continue"} default button "Continue" cancel button "Cancel")

    if action is "Continue" then
        if (count of observedFolders) is 0 then
            display alert "Choose at least one folder." as warning
        else
            exit repeat
        end if
    else if action is "Add Folders..." then
        set addedFolders to choose folder with prompt "Add folders to watch:" with multiple selections allowed
        repeat with addedFolder in addedFolders
            set folderPath to POSIX path of addedFolder
            if folderPath is not in observedFolders then set end of observedFolders to folderPath
        end repeat
    else if action is "Remove Folders..." then
        set foldersToRemove to choose from list observedFolders with prompt "Choose folders to stop watching:" with multiple selections allowed
        if foldersToRemove is not false then
            repeat with folderToRemove in foldersToRemove
                set observedFolders to observedFolders whose contents is not (contents of folderToRemove)
            end repeat
        end if
    end if
end repeat

set AppleScript's text item delimiters to linefeed
return observedFolders as text
APPLESCRIPT
)

folders=("${(@f)selected}")

if (( ${#folders[@]} == 0 )); then
    print -u2 "Select at least one folder. Setup cancelled."
    exit 1
fi

mkdir -p "$config_directory" "$home_directory/Library/LaunchAgents"

folders_json="["
for folder in "${folders[@]}"; do
    escaped_folder=${folder//\\/\\\\}
    escaped_folder=${escaped_folder//\"/\\\"}
    [[ "$folders_json" != "[" ]] && folders_json+=", "
    folders_json+="\"$escaped_folder\""
done
folders_json+="]"
printf '{\n  "observedFolders": %s\n}\n' "$folders_json" > "$config_file"

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

print "Video Tagging is configured for: ${folders[*]}"
