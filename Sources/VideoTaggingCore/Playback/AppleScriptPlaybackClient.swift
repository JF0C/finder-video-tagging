import AppKit
import Foundation

@MainActor
final class AppleScriptPlaybackClient {
    func items() -> [PlaybackItem] {
        vlcItems() + quickTimeItems()
    }

    func resume(_ item: PlaybackItem, at time: Double) {
        switch item.player {
        case .vlc:
            _ = run(
                """
                tell application id "org.videolan.vlc"
                    set current time to \(time)
                    play
                end tell
                """)
        case .quickTime:
            let path = literal(item.url.path)
            _ = run(
                """
                tell application id "com.apple.QuickTimePlayerX"
                    repeat with movieDocument in documents
                        if POSIX path of file of movieDocument is \(path) then
                            set current time of movieDocument to \(time)
                            play movieDocument
                        end if
                    end repeat
                end tell
                """)
        }
    }

    private func vlcItems() -> [PlaybackItem] {
        guard isRunning("org.videolan.vlc") else { return [] }
        return PlaybackPolicy.parse(
            run(
                """
                tell application id "org.videolan.vlc"
                    try
                        return (path of current item) & tab & (current time as text) & tab & (duration of current item as text) & tab & (playing as text)
                    on error
                        return ""
                    end try
                end tell
                """),
            player: .vlc
        )
    }

    private func quickTimeItems() -> [PlaybackItem] {
        guard isRunning("com.apple.QuickTimePlayerX") else { return [] }
        return PlaybackPolicy.parse(
            run(
                """
                tell application id "com.apple.QuickTimePlayerX"
                    set results to {}
                    repeat with movieDocument in documents
                        set mediaFile to file of movieDocument
                        set end of results to (POSIX path of mediaFile) & tab & (current time of movieDocument as text) & tab & (duration of movieDocument as text) & tab & (playing of movieDocument as text)
                    end repeat
                    return results
                end tell
                """),
            player: .quickTime
        )
    }

    private func isRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    private func run(_ script: String) -> String {
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

    private func literal(_ value: String) -> String {
        "\"\(value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\""))\""
    }
}
