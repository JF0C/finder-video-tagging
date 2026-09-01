import Foundation
import VideoTaggingCore

let configuration = Configuration.load()
let observedFolders = configuration.observedFolders.map {
    URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
}
let tagManager = TagManager()
let watcher = FolderWatcher(roots: observedFolders, tagManager: tagManager)
let browserPlaybackClient: BrowserSessionService? = {
    guard configuration.browserPlaybackResumeEnabled == true,
        configuration.playbackResume != nil
    else { return nil }
    let socketPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/VideoTagging/browser.sock").path
    let safariDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(
            "Library/Group Containers/group.com.findervideotagging.shared",
            isDirectory: true
        )
    do {
        try FileManager.default.createDirectory(
            at: safariDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return try BrowserSessionService(
            socketPath: socketPath,
            additionalSocketPaths: [safariDirectory.appendingPathComponent("browser.sock").path],
            report: {
                fputs("\($0)\n", stderr)
            })
    } catch {
        fputs("Browser playback resume is unavailable: \(error)\n", stderr)
        return nil
    }
}()
let playerMonitor = PlayerMonitor(
    tagManager: tagManager,
    roots: observedFolders,
    viewedAtPercentage: configuration.viewedAtPercentage,
    viewedSecondsBeforeEnd: configuration.viewedSecondsBeforeEnd,
    playbackResume: configuration.playbackResume,
    browserPlaybackClient: browserPlaybackClient
)

watcher.start()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    Task { @MainActor in
        playerMonitor.poll()
    }
}

print("Video tagging is watching \(observedFolders.map(\.path).joined(separator: ", ")).")
RunLoop.main.run()
