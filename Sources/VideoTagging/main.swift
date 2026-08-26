import Foundation
import VideoTaggingCore

let configuration = Configuration.load()
let observedFolders = configuration.observedFolders.map {
    URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
}
let tagManager = TagManager()
let watcher = FolderWatcher(roots: observedFolders, tagManager: tagManager)
let playerMonitor = PlayerMonitor(
    tagManager: tagManager,
    roots: observedFolders,
    viewedAtPercentage: configuration.viewedAtPercentage,
    viewedSecondsBeforeEnd: configuration.viewedSecondsBeforeEnd,
    playbackResume: configuration.playbackResume
)

watcher.start()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    Task { @MainActor in
        playerMonitor.poll()
    }
}

print("Video tagging is watching \(observedFolders.map(\.path).joined(separator: ", ")).")
RunLoop.main.run()
