public enum PlaybackResumeAction: Equatable, Sendable {
    case none
    case restore(targetUID: String, items: [PlaybackItem], rewindSeconds: Double)
}

public struct PlaybackResumeCoordinator: Sendable {
    private var lastOutputUID: String?
    private var pendingItems: [PlaybackItem] = []

    public init() {}

    public mutating func outputChanged(
        to currentUID: String,
        items: [PlaybackItem],
        configuration: PlaybackResumeConfiguration
    ) -> PlaybackResumeAction {
        defer { lastOutputUID = currentUID }
        guard let lastOutputUID, lastOutputUID != currentUID else { return .none }
        if lastOutputUID == configuration.targetOutput.uid,
            currentUID == configuration.headphonesOutput.uid
        {
            pendingItems = items.filter(\.isPlaying)
            return .none
        }
        guard lastOutputUID == configuration.headphonesOutput.uid,
            currentUID != configuration.headphonesOutput.uid,
            !pendingItems.isEmpty
        else { return .none }
        let itemsToResume = pendingItems
        pendingItems = []
        return .restore(
            targetUID: configuration.targetOutput.uid,
            items: itemsToResume,
            rewindSeconds: configuration.rewindSeconds
        )
    }
}
