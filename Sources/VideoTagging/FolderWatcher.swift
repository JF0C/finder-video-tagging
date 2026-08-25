import CoreServices
import Foundation

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
