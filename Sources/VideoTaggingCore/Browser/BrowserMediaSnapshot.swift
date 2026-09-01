public struct BrowserMediaSnapshot: Equatable, Sendable {
    public let identity: BrowserMediaIdentity
    public let isPlaying: Bool

    public init(identity: BrowserMediaIdentity, isPlaying: Bool) {
        self.identity = identity
        self.isPlaying = isPlaying
    }
}
