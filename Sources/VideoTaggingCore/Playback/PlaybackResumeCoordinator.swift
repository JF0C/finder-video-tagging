public enum PlaybackResumeAction: Equatable, Sendable {
    case none
    case restore(
        targetUID: String,
        localItems: [PlaybackItem],
        browserSessions: [BrowserMediaIdentity],
        rewindSeconds: Double
    )
}

public struct PlaybackResumeCoordinator: Sendable {
    private var lastOutputUID: String?
    private var pendingItems: [PlaybackItem] = []
    private var pendingBrowserSessions: [BrowserMediaIdentity] = []

    public init() {}

    public mutating func outputChanged(
        to currentUID: String,
        items: [PlaybackItem],
        browserMedia: [BrowserMediaSnapshot] = [],
        configuration: PlaybackResumeConfiguration
    ) -> PlaybackResumeAction {
        defer { lastOutputUID = currentUID }
        guard let lastOutputUID, lastOutputUID != currentUID else { return .none }
        if lastOutputUID == configuration.targetOutput.uid,
            currentUID == configuration.headphonesOutput.uid
        {
            pendingItems = items.filter(\.isPlaying)
            pendingBrowserSessions = browserMedia.filter(\.isPlaying).map(\.identity)
            return .none
        }
        guard lastOutputUID == configuration.headphonesOutput.uid,
            currentUID != configuration.headphonesOutput.uid,
            !pendingItems.isEmpty || !pendingBrowserSessions.isEmpty
        else { return .none }
        let itemsToResume = pendingItems
        let browserSessionsToResume = pendingBrowserSessions
        pendingItems = []
        pendingBrowserSessions = []
        return .restore(
            targetUID: configuration.targetOutput.uid,
            localItems: itemsToResume,
            browserSessions: browserSessionsToResume,
            rewindSeconds: configuration.rewindSeconds
        )
    }
}
