@MainActor
public protocol BrowserPlaybackClient: AnyObject {
    func freshSnapshots() -> [BrowserMediaSnapshot]
    func resume(_ identities: [BrowserMediaIdentity], rewindSeconds: Double)
}
