public struct BrowserMediaIdentity: Codable, Equatable, Hashable, Sendable {
    public let browser: BrowserKind
    public let connectionID: String
    public let tabID: Int
    public let frameID: Int
    public let documentID: String
    public let sessionID: String

    public init(
        browser: BrowserKind,
        connectionID: String,
        tabID: Int,
        frameID: Int,
        documentID: String,
        sessionID: String
    ) {
        self.browser = browser
        self.connectionID = connectionID
        self.tabID = tabID
        self.frameID = frameID
        self.documentID = documentID
        self.sessionID = sessionID
    }
}
