import Foundation

public struct BrowserMediaRegistry: Sendable {
    private struct Entry: Sendable {
        let snapshot: BrowserMediaSnapshot
        let observedAt: TimeInterval
    }

    private let freshnessInterval: TimeInterval
    private var entries: [BrowserMediaIdentity: Entry] = [:]

    public init(freshnessInterval: TimeInterval = 3) {
        self.freshnessInterval = freshnessInterval
    }

    public mutating func update(_ message: BrowserMediaStateMessage, receivedAt: TimeInterval) {
        guard message.version == BrowserProtocol.version,
            message.type == "media-state",
            message.currentTime.map({ $0.isFinite && $0 >= 0 }) ?? true,
            message.duration.map({ $0.isFinite && $0 >= 0 }) ?? true,
            isValid(message.identity)
        else { return }
        if message.event == "removed" || message.ended {
            entries.removeValue(forKey: message.identity)
            return
        }
        entries[message.identity] = Entry(
            snapshot: BrowserMediaSnapshot(
                identity: message.identity,
                isPlaying: message.isPlaying
            ),
            observedAt: receivedAt
        )
    }

    public mutating func disconnect(connectionID: String) {
        entries = entries.filter { $0.key.connectionID != connectionID }
    }

    public mutating func freshSnapshots(at currentTime: TimeInterval) -> [BrowserMediaSnapshot] {
        entries = entries.filter { currentTime - $0.value.observedAt <= freshnessInterval }
        return entries.values.map(\.snapshot)
    }

    public func contains(_ identity: BrowserMediaIdentity) -> Bool {
        entries[identity] != nil
    }

    private func isValid(_ identity: BrowserMediaIdentity) -> Bool {
        (1...128).contains(identity.connectionID.count)
            && identity.tabID >= 0
            && identity.frameID >= 0
            && (1...128).contains(identity.documentID.count)
            && (1...128).contains(identity.sessionID.count)
    }
}
