import AppKit
import Foundation

final class PlayerMonitor {
    private let tagManager: TagManager
    private let roots: [URL]

    init(tagManager: TagManager, roots: [URL]) {
        self.tagManager = tagManager
        self.roots = roots.map(\.standardizedFileURL)
    }

    func poll() {
        (vlcItems() + quickTimeItems()).forEach { item in
            guard item.duration > 0,
                tagManager.isSupportedMedia(item.url),
                isInObservedFolder(item.url)
            else {
                return
            }

            let progress = item.currentTime / item.duration
            tagManager.apply(progress >= 0.85 ? .viewed : .watching, to: item.url)
        }
    }

    private func vlcItems() -> [PlaybackItem] {
        guard isRunning(bundleIdentifier: "org.videolan.vlc") else {
            return []
        }

        let script = """
            tell application id "org.videolan.vlc"
                if playing then
                    return (path of current item) & tab & (current time as text) & tab & (duration of current item as text)
                end if
            end tell
            return ""
            """
        return parseItems(runAppleScript(script))
    }

    private func quickTimeItems() -> [PlaybackItem] {
        guard isRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") else {
            return []
        }

        let script = """
            tell application id "com.apple.QuickTimePlayerX"
                set results to {}
                repeat with movieDocument in documents
                    if playing of movieDocument then
                        set mediaFile to file of movieDocument
                        set end of results to (POSIX path of mediaFile) & tab & (current time of movieDocument as text) & tab & (duration of movieDocument as text)
                    end if
                end repeat
                return results
            end tell
            """
        return parseItems(runAppleScript(script))
    }

    private func isRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier == bundleIdentifier
        }
    }

    private func isInObservedFolder(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return roots.contains { root in
            path == root.path || path.hasPrefix(root.path + "/")
        }
    }

    private func runAppleScript(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "AppleScript", "-e", script]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "" }
            return String(
                decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        } catch {
            return ""
        }
    }

    private func parseItems(_ output: String) -> [PlaybackItem] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let values = line.split(separator: "\t", maxSplits: 2).map(String.init)
                guard values.count == 3,
                    let currentTime = Double(values[1]),
                    let duration = Double(values[2])
                else {
                    return nil
                }
                return PlaybackItem(
                    url: URL(fileURLWithPath: values[0]),
                    currentTime: currentTime,
                    duration: duration
                )
            }
    }
}
