import Foundation

enum FolderWatcherStabilityAction: Equatable {
    case stop
    case retry
    case tag
    case timedOut
}

enum FolderWatcherPolicy {
    static func mediaURLs(
        at url: URL,
        fileExists: Bool,
        isSupportedMedia: (URL) -> Bool,
        descendants: () -> [URL]
    ) -> [URL] {
        guard fileExists else { return [] }
        if isSupportedMedia(url) {
            return [url]
        }
        return descendants().filter(isSupportedMedia)
    }

    static func stabilityAction(
        initialSize: Int?,
        fileExists: Bool,
        currentSize: Int?,
        attemptsRemaining: Int
    ) -> FolderWatcherStabilityAction {
        guard let initialSize, fileExists, let currentSize else { return .stop }
        if initialSize == currentSize {
            return .tag
        }
        return attemptsRemaining > 1 ? .retry : .timedOut
    }
}
