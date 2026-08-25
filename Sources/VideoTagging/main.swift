import AppKit
import CoreServices
import Darwin
import Foundation

enum ManagedTag: String, CaseIterable {
    case new = "New"
    case watching = "Watching"
    case viewed = "Viewed"

    var finderColor: Int {
        switch self {
        case .new: 4
        case .watching: 5
        case .viewed: 1
        }
    }

    var finderTagEntry: String {
        finderColor == 0 ? rawValue : "\(rawValue)\n\(finderColor)"
    }
}

struct PlaybackItem {
    let url: URL
    let currentTime: Double
    let duration: Double
}

struct Configuration: Codable {
    let observedFolders: [String]

    static func load() -> [URL] {
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let configURL =
            homeDirectory
            .appendingPathComponent("Library/Application Support/VideoTagging/config.json")
        let defaultFolders = ["Downloads", "Movies"].map {
            homeDirectory.appendingPathComponent($0, isDirectory: true)
        }

        guard let data = try? Data(contentsOf: configURL),
            let configuration = try? JSONDecoder().decode(Configuration.self, from: data)
        else {
            return defaultFolders.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        let folders = configuration.observedFolders.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        }
        let existingFolders = folders.filter { FileManager.default.fileExists(atPath: $0.path) }
        let uniqueFolders = Dictionary(grouping: existingFolders, by: \.path).compactMap {
            $0.value.first
        }

        if uniqueFolders.isEmpty {
            fputs("No configured observed folders exist; using Downloads and Movies.\n", stderr)
            return defaultFolders.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        return uniqueFolders
    }
}

final class TagManager: @unchecked Sendable {
    private let finderInfoAttribute = "com.apple.FinderInfo"
    private let finderInfoColorFlagsOffset = 9
    private let finderInfoColorFlagsMask: UInt8 = 0x0E
    private let conflictingColorTagNames: Set<String> = [
        "Blau", "Grün", "Gelb", "Grau", "Green", "Yellow", "Gray",
    ]

    func apply(_ managedTag: ManagedTag, to url: URL, onlyIfUnmanaged: Bool = false) {
        guard isSupportedMedia(url), FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let existingEntries = try readFinderTagEntries(from: url)
            let hasManagedTag = existingEntries.contains {
                ManagedTag(rawValue: finderTagName(from: $0)) != nil
            }

            if onlyIfUnmanaged && hasManagedTag {
                removeConflictingColorTags(from: existingEntries, url: url)
                try clearLegacyFinderColor(from: url)
                return
            }

            let retainedTags =
                existingEntries.filter {
                    let tagName = finderTagName(from: $0)
                    return ManagedTag(rawValue: tagName) == nil
                        && !conflictingColorTagNames.contains(tagName)
                }
            let updatedTags = retainedTags + [managedTag.finderTagEntry]
            if Set(updatedTags) != Set(existingEntries) {
                let replacesExistingState = existingEntries.contains {
                    guard let existingTag = ManagedTag(rawValue: finderTagName(from: $0)) else {
                        return false
                    }
                    return existingTag != managedTag
                }
                if replacesExistingState {
                    try writeFinderTags(retainedTags, to: url)
                }
                try writeFinderTags(updatedTags, to: url)
                print("Tagged \(url.path) as \(managedTag.rawValue)")
            }
            try clearLegacyFinderColor(from: url)
        } catch {
            fputs("Could not tag \(url.path): \(error)\n", stderr)
        }
    }

    func isSupportedMedia(_ url: URL) -> Bool {
        ["mkv", "mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    private func readFinderTagEntries(from url: URL) throws -> [String] {
        let attribute = "com.apple.metadata:_kMDItemUserTags"
        let length = getxattr(url.path, attribute, nil, 0, 0, 0)

        guard length >= 0 else {
            if errno == ENOATTR {
                return []
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(url.path, attribute, bytes.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
            ?? []
    }

    private func finderTagName(from entry: String) -> String {
        guard let separator = entry.lastIndex(of: "\n") else {
            return entry
        }
        return String(entry[..<separator])
    }

    private func removeConflictingColorTags(from entries: [String], url: URL) {
        let updatedEntries = entries.filter {
            !conflictingColorTagNames.contains(finderTagName(from: $0))
        }
        guard Set(updatedEntries) != Set(entries) else {
            return
        }

        do {
            try writeFinderTags(updatedEntries, to: url)
            print("Removed conflicting color tags from \(url.path)")
        } catch {
            fputs("Could not clean up tags for \(url.path): \(error)\n", stderr)
        }
    }

    private func clearLegacyFinderColor(from url: URL) throws {
        let length = getxattr(url.path, finderInfoAttribute, nil, 0, 0, 0)

        guard length >= 0 else {
            if errno == ENOATTR {
                return
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard length > finderInfoColorFlagsOffset else {
            return
        }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(url.path, finderInfoAttribute, bytes.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let updatedFlags = data[finderInfoColorFlagsOffset] & ~finderInfoColorFlagsMask
        guard updatedFlags != data[finderInfoColorFlagsOffset] else {
            return
        }
        data[finderInfoColorFlagsOffset] = updatedFlags

        let writeResult = data.withUnsafeBytes { bytes in
            setxattr(
                url.path,
                finderInfoAttribute,
                bytes.baseAddress,
                bytes.count,
                0,
                0
            )
        }
        guard writeResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func writeFinderTags(_ entries: [String], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: entries,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { bytes in
            setxattr(
                url.path,
                "com.apple.metadata:_kMDItemUserTags",
                bytes.baseAddress,
                bytes.count,
                0,
                0
            )
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}

final class FolderWatcher: @unchecked Sendable {
    private let tagManager: TagManager
    private let roots: [URL]
    private var stream: FSEventStreamRef?

    init(roots: [URL], tagManager: TagManager) {
        self.roots = roots
        self.tagManager = tagManager
    }

    func start() {
        let paths = roots.map(\.path) as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, eventCount, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
                let paths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)

                for index in 0..<Int(eventCount) {
                    let flags = eventFlags[index]
                    guard
                        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
                            || flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)
                                != 0
                    else {
                        continue
                    }
                    guard let path = paths[index] else {
                        continue
                    }
                    watcher.handleChange(at: URL(fileURLWithPath: String(cString: path)))
                }
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        )

        guard let stream else {
            fatalError("Could not create the file-system event stream.")
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        guard FSEventStreamStart(stream) else {
            fatalError("Could not start the file-system event stream.")
        }
    }

    private func handleChange(at url: URL) {
        // A move or download can be reported before its final write completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, tagManager] in
            guard let self, FileManager.default.fileExists(atPath: url.path) else {
                return
            }

            if tagManager.isSupportedMedia(url) {
                self.tagWhenStable(url)
                return
            }

            guard
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            else {
                return
            }

            for case let nestedURL as URL in enumerator {
                guard tagManager.isSupportedMedia(nestedURL) else {
                    continue
                }
                self.tagWhenStable(nestedURL)
            }
        }
    }

    private func tagWhenStable(_ url: URL, attemptsRemaining: Int = 30) {
        guard
            let initialSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, tagManager] in
            guard let self, FileManager.default.fileExists(atPath: url.path),
                let currentSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            else {
                return
            }

            guard initialSize == currentSize else {
                guard attemptsRemaining > 1 else {
                    fputs(
                        "File did not finish downloading before tagging timed out: \(url.path)\n",
                        stderr)
                    return
                }
                self.tagWhenStable(url, attemptsRemaining: attemptsRemaining - 1)
                return
            }

            tagManager.apply(.new, to: url, onlyIfUnmanaged: true)
        }
    }
}

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

let observedFolders = Configuration.load()
let tagManager = TagManager()
let watcher = FolderWatcher(roots: observedFolders, tagManager: tagManager)
nonisolated(unsafe) let playerMonitor = PlayerMonitor(
    tagManager: tagManager, roots: observedFolders)

watcher.start()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    playerMonitor.poll()
}

print("Video tagging is watching \(observedFolders.map(\.path).joined(separator: ", ")).")
RunLoop.main.run()
