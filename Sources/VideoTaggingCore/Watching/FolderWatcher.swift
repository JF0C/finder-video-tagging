import CoreServices
import Foundation

public final class FolderWatcher: @unchecked Sendable {
    private let tagManager: TagManager
    private let roots: [URL]
    private var stream: FSEventStreamRef?

    public init(roots: [URL], tagManager: TagManager) {
        self.roots = roots
        self.tagManager = tagManager
    }

    public func start() {
        let paths = roots.map(\.path) as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, count, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
                let paths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                for index in 0..<Int(count) {
                    let flags = eventFlags[index]
                    let relevant =
                        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
                        || flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
                    guard relevant, let path = paths[index] else { continue }
                    watcher.handleChange(at: URL(fileURLWithPath: String(cString: path)))
                }
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        guard let stream else { fatalError("Could not create the file-system event stream.") }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        guard FSEventStreamStart(stream) else {
            fatalError("Could not start the file-system event stream.")
        }
    }

    private func handleChange(at url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, tagManager] in
            guard let self else { return }
            let mediaURLs = FolderWatcherPolicy.mediaURLs(
                at: url,
                fileExists: FileManager.default.fileExists(atPath: url.path),
                isSupportedMedia: tagManager.isSupportedMedia,
                descendants: { self.descendants(of: url) }
            )
            for mediaURL in mediaURLs {
                self.tagWhenStable(mediaURL)
            }
        }
    }

    private func descendants(of url: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }
        return enumerator.compactMap { $0 as? URL }
    }

    private func tagWhenStable(_ url: URL, attemptsRemaining: Int = 30) {
        guard let initialSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, tagManager] in
            guard let self else { return }
            let action = FolderWatcherPolicy.stabilityAction(
                initialSize: initialSize,
                fileExists: FileManager.default.fileExists(atPath: url.path),
                currentSize: try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                attemptsRemaining: attemptsRemaining
            )
            switch action {
            case .stop:
                return
            case .retry:
                self.tagWhenStable(url, attemptsRemaining: attemptsRemaining - 1)
            case .tag:
                tagManager.apply(.new, to: url, onlyIfUnmanaged: true)
            case .timedOut:
                fputs(
                    "File did not finish downloading before tagging timed out: \(url.path)\n",
                    stderr)
            }
        }
    }
}
