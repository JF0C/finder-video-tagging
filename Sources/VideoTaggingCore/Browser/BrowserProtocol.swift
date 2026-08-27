import Foundation

public enum BrowserProtocol {
    public static let version = 1
    public static let maximumMessageBytes = 65_536
}

public enum BrowserResumeStatus: String, Codable, Sendable {
    case resumed
    case sessionNotFound = "session-not-found"
    case documentChanged = "document-changed"
    case mediaEnded = "media-ended"
    case seekFailed = "seek-failed"
    case playRejected = "play-rejected"
}

public struct BrowserConnectedMessage: Codable, Equatable, Sendable {
    public let version: Int
    public let type: String
    public let browser: BrowserKind
    public let connectionID: String

    enum CodingKeys: String, CodingKey {
        case version, type, browser
        case connectionID = "connectionId"
    }
}

public struct BrowserMediaStateMessage: Codable, Equatable, Sendable {
    public let version: Int
    public let type: String
    public let identity: BrowserMediaIdentity
    public let event: String
    public let isPlaying: Bool
    public let ended: Bool
    public let currentTime: Double?
    public let duration: Double?

    enum CodingKeys: String, CodingKey {
        case version, type, browser
        case connectionID = "connectionId"
        case tabID = "tabId"
        case frameID = "frameId"
        case documentID = "documentId"
        case sessionID = "sessionId"
        case event, isPlaying, ended, currentTime, duration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        type = try values.decode(String.self, forKey: .type)
        identity = BrowserMediaIdentity(
            browser: try values.decode(BrowserKind.self, forKey: .browser),
            connectionID: try values.decode(String.self, forKey: .connectionID),
            tabID: try values.decode(Int.self, forKey: .tabID),
            frameID: try values.decode(Int.self, forKey: .frameID),
            documentID: try values.decode(String.self, forKey: .documentID),
            sessionID: try values.decode(String.self, forKey: .sessionID)
        )
        event = try values.decode(String.self, forKey: .event)
        isPlaying = try values.decode(Bool.self, forKey: .isPlaying)
        ended = try values.decode(Bool.self, forKey: .ended)
        currentTime = try values.decodeIfPresent(Double.self, forKey: .currentTime)
        duration = try values.decodeIfPresent(Double.self, forKey: .duration)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(type, forKey: .type)
        try values.encode(identity.browser, forKey: .browser)
        try values.encode(identity.connectionID, forKey: .connectionID)
        try values.encode(identity.tabID, forKey: .tabID)
        try values.encode(identity.frameID, forKey: .frameID)
        try values.encode(identity.documentID, forKey: .documentID)
        try values.encode(identity.sessionID, forKey: .sessionID)
        try values.encode(event, forKey: .event)
        try values.encode(isPlaying, forKey: .isPlaying)
        try values.encode(ended, forKey: .ended)
        try values.encodeIfPresent(currentTime, forKey: .currentTime)
        try values.encodeIfPresent(duration, forKey: .duration)
    }
}

public struct BrowserResumeResultMessage: Codable, Equatable, Sendable {
    public let version: Int
    public let type: String
    public let status: BrowserResumeStatus
}

public struct BrowserResumeMessage: Codable, Equatable, Sendable {
    public let version: Int
    public let type: String
    public let identity: BrowserMediaIdentity
    public let rewindSeconds: Double

    public init(identity: BrowserMediaIdentity, rewindSeconds: Double) {
        version = BrowserProtocol.version
        type = "resume-media"
        self.identity = identity
        self.rewindSeconds = rewindSeconds
    }

    enum CodingKeys: String, CodingKey {
        case version, type, browser
        case connectionID = "connectionId"
        case tabID = "tabId"
        case frameID = "frameId"
        case documentID = "documentId"
        case sessionID = "sessionId"
        case rewindSeconds
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(type, forKey: .type)
        try values.encode(identity.browser, forKey: .browser)
        try values.encode(identity.connectionID, forKey: .connectionID)
        try values.encode(identity.tabID, forKey: .tabID)
        try values.encode(identity.frameID, forKey: .frameID)
        try values.encode(identity.documentID, forKey: .documentID)
        try values.encode(identity.sessionID, forKey: .sessionID)
        try values.encode(rewindSeconds, forKey: .rewindSeconds)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        type = try values.decode(String.self, forKey: .type)
        identity = BrowserMediaIdentity(
            browser: try values.decode(BrowserKind.self, forKey: .browser),
            connectionID: try values.decode(String.self, forKey: .connectionID),
            tabID: try values.decode(Int.self, forKey: .tabID),
            frameID: try values.decode(Int.self, forKey: .frameID),
            documentID: try values.decode(String.self, forKey: .documentID),
            sessionID: try values.decode(String.self, forKey: .sessionID)
        )
        rewindSeconds = try values.decode(Double.self, forKey: .rewindSeconds)
    }
}
