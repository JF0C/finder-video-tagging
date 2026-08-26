import AppKit
import Foundation

@MainActor
final class PlayerMonitor {
    private let tagManager: TagManager
    private let roots: [URL]
    private let viewedAtPercentage: Double?
    private let viewedSecondsBeforeEnd: Double?
    private let playbackResume: PlaybackResumeConfiguration?
    private var lastOutput: AudioOutputDevice?
    private var pendingResume: [PlaybackItem] = []

    init(
        tagManager: TagManager,
        roots: [URL],
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?,
        playbackResume: PlaybackResumeConfiguration?
    ) {
        self.tagManager = tagManager
        self.roots = roots.map(\.standardizedFileURL)
        self.viewedAtPercentage = viewedAtPercentage
        self.viewedSecondsBeforeEnd = viewedSecondsBeforeEnd
        self.playbackResume = playbackResume
    }

    func poll() {
        let items = vlcItems() + quickTimeItems()
        handleAudioRouteChange(items: items)

        items.filter(\.isPlaying).forEach { item in
            guard item.duration > 0,
                tagManager.isSupportedMedia(item.url),
                isInObservedFolder(item.url)
            else {
                return
            }

            let isViewed =
                (viewedAtPercentage.map {
                    item.currentTime / item.duration >= $0 / 100
                } ?? false)
                || (viewedSecondsBeforeEnd.map {
                    item.duration - item.currentTime <= $0
                } ?? false)
            tagManager.apply(isViewed ? .viewed : .watching, to: item.url)
        }
    }

    private func vlcItems() -> [PlaybackItem] {
        guard isRunning(bundleIdentifier: "org.videolan.vlc") else {
            return []
        }

        let script = """
            tell application id "org.videolan.vlc"
                try
                    return (path of current item) & tab & (current time as text) & tab & (duration of current item as text) & tab & (playing as text)
                on error
                    return ""
                end try
            end tell
            """
        return parseItems(runAppleScript(script), player: .vlc)
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
                        set isPlaying to true
                    else
                        set isPlaying to false
                    end if
                    set mediaFile to file of movieDocument
                    set end of results to (POSIX path of mediaFile) & tab & (current time of movieDocument as text) & tab & (duration of movieDocument as text) & tab & (isPlaying as text)
                end repeat
                return results
            end tell
            """
        return parseItems(runAppleScript(script), player: .quickTime)
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

    private func parseItems(_ output: String, player: Player) -> [PlaybackItem] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let values = line.split(separator: "\t", maxSplits: 3).map(String.init)
                guard values.count == 4,
                    let currentTime = Double(values[1]),
                    let duration = Double(values[2]),
                    let isPlaying = Bool(values[3])
                else {
                    return nil
                }
                return PlaybackItem(
                    player: player,
                    url: URL(fileURLWithPath: values[0]),
                    currentTime: currentTime,
                    duration: duration,
                    isPlaying: isPlaying
                )
            }
    }

    private func handleAudioRouteChange(items: [PlaybackItem]) {
        guard let playbackResume,
            let currentOutput = try? AudioOutputDevices.current()
        else {
            return
        }
        defer { lastOutput = currentOutput }

        guard let lastOutput, lastOutput.uid != currentOutput.uid else {
            return
        }

        if lastOutput.uid == playbackResume.targetOutput.uid,
            currentOutput.uid == playbackResume.headphonesOutput.uid
        {
            pendingResume = items.filter(\.isPlaying)
            return
        }

        guard lastOutput.uid == playbackResume.headphonesOutput.uid,
            currentOutput.uid != playbackResume.headphonesOutput.uid,
            !pendingResume.isEmpty
        else {
            return
        }

        let itemsToResume = pendingResume
        pendingResume = []
        do {
            try AudioOutputDevices.setCurrent(toUID: playbackResume.targetOutput.uid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.resume(itemsToResume, rewindSeconds: playbackResume.rewindSeconds)
            }
        } catch {
            fputs("Could not restore audio output: \(error)\n", stderr)
        }
    }

    private func resume(_ pendingItems: [PlaybackItem], rewindSeconds: Double) {
        let currentItems = vlcItems() + quickTimeItems()
        for pendingItem in pendingItems {
            guard
                let currentItem = currentItems.first(where: {
                    $0.player == pendingItem.player && $0.url == pendingItem.url && !$0.isPlaying
                })
            else {
                continue
            }
            let resumeTime = max(0, currentItem.currentTime - rewindSeconds)
            switch currentItem.player {
            case .vlc:
                _ = runAppleScript(
                    """
                    tell application id "org.videolan.vlc"
                        set current time to \(resumeTime)
                        play
                    end tell
                    """
                )
            case .quickTime:
                let path = appleScriptStringLiteral(currentItem.url.path)
                _ = runAppleScript(
                    """
                    tell application id "com.apple.QuickTimePlayerX"
                        repeat with movieDocument in documents
                            if POSIX path of file of movieDocument is \(path) then
                                set current time of movieDocument to \(resumeTime)
                                play movieDocument
                            end if
                        end repeat
                    end tell
                    """
                )
            }
        }
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        "\"\(value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\""))\""
    }
}
