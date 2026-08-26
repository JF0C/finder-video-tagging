import Foundation

@MainActor
struct PlayerMonitorDependencies {
    let items: () -> [PlaybackItem]
    let isSupportedMedia: (URL) -> Bool
    let applyTag: (ManagedTag, URL) -> Void
    let currentOutput: () throws -> AudioOutputDevice?
    let setCurrentOutput: (String) throws -> Void
    let scheduleResume: (@escaping @MainActor () -> Void) -> Void
    let resume: (PlaybackItem, Double) -> Void
    let reportError: (String) -> Void

    static func live(tagManager: TagManager) -> Self {
        let playbackClient = AppleScriptPlaybackClient()
        return Self(
            items: playbackClient.items,
            isSupportedMedia: tagManager.isSupportedMedia,
            applyTag: { tagManager.apply($0, to: $1) },
            currentOutput: AudioOutputDevices.current,
            setCurrentOutput: AudioOutputDevices.setCurrent,
            scheduleResume: { action in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: action)
            },
            resume: playbackClient.resume,
            reportError: { fputs("\($0)\n", stderr) }
        )
    }
}
