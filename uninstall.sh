#!/bin/zsh
set -euo pipefail

label="com.video-tagging"
legacy_label="com.jan.video-tagging"
console_user=$(/usr/bin/stat -f %Su /dev/console)

if [[ "$console_user" == "root" || "$console_user" != "$(id -un)" ]]; then
    print -u2 "Run uninstall from the logged-in macOS user account."
    exit 1
fi

home_directory=$(dscl . -read "/Users/$console_user" NFSHomeDirectory | awk '{print $2}')
user_id=$(id -u)
host_name="com.findervideotagging.browser"

launchctl bootout "gui/$user_id/$label" 2>/dev/null || true
launchctl bootout "gui/$user_id/$legacy_label" 2>/dev/null || true

rm -f \
    "$home_directory/Library/LaunchAgents/$label.plist" \
    "$home_directory/Library/LaunchAgents/$legacy_label.plist" \
    "$home_directory/Library/Logs/video-tagging.log" \
    "$home_directory/Library/Logs/video-tagging-error.log" \
    "$home_directory/Library/Application Support/Google/Chrome/NativeMessagingHosts/$host_name.json" \
    "$home_directory/Library/Application Support/Mozilla/NativeMessagingHosts/$host_name.json"
rm -rf "$home_directory/Library/Application Support/VideoTagging"
rm -rf "$home_directory/Library/Group Containers/group.com.findervideotagging.shared"

print "Video Tagging has been uninstalled."