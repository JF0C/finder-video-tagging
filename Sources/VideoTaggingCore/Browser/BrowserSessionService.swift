import Foundation

@MainActor
public final class BrowserSessionService: BrowserPlaybackClient {
    private let now: () -> TimeInterval
    private let report: (String) -> Void
    private var registry = BrowserMediaRegistry()
    private var clientsByConnection: [String: BrowserIPCServer.ClientID] = [:]
    private var connectionsByClient: [BrowserIPCServer.ClientID: String] = [:]
    private var servers: [BrowserIPCServer] = []

    public init(
        socketPath: String,
        additionalSocketPaths: [String] = [],
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        report: @escaping (String) -> Void = { _ in }
    ) throws {
        self.now = now
        self.report = report
        for path in [socketPath] + additionalSocketPaths {
            let server = BrowserIPCServer(
                path: path,
                onMessage: { [weak self] clientID, data in
                    DispatchQueue.main.async {
                        self?.receive(data, from: clientID)
                    }
                },
                onDisconnect: { [weak self] clientID in
                    DispatchQueue.main.async {
                        self?.disconnect(clientID)
                    }
                }
            )
            do {
                try server.start()
                servers.append(server)
            } catch {
                servers.forEach { $0.stop() }
                throw error
            }
        }
    }

    public func freshSnapshots() -> [BrowserMediaSnapshot] {
        registry.freshSnapshots(at: now())
    }

    public func resume(_ identities: [BrowserMediaIdentity], rewindSeconds: Double) {
        for identity in identities where registry.contains(identity) {
            guard let clientID = clientsByConnection[identity.connectionID] else { continue }
            do {
                let message = BrowserResumeMessage(
                    identity: identity,
                    rewindSeconds: max(0, rewindSeconds)
                )
                try send(JSONEncoder().encode(message), to: clientID)
            } catch {
                report("Could not send browser resume command: \(error)")
            }
        }
    }

    func receive(_ data: Data, from clientID: BrowserIPCServer.ClientID) {
        guard data.count <= BrowserProtocol.maximumMessageBytes,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["version"] as? Int == BrowserProtocol.version,
            let type = object["type"] as? String,
            Set(object.keys.map { $0.lowercased() }).isDisjoint(with: ["url", "title"])
        else { return }
        if type == "connected" {
            if registerConnection(object, clientID: clientID) {
                sendConnectionAcknowledgment(to: clientID)
            }
        } else if type == "media-state",
            let message = try? JSONDecoder().decode(BrowserMediaStateMessage.self, from: data),
            clientsByConnection[message.identity.connectionID] == clientID
        {
            registry.update(message, receivedAt: now())
        } else if type == "resume-result",
            let result = try? JSONDecoder().decode(BrowserResumeResultMessage.self, from: data)
        {
            report("Browser resume result: \(result.status.rawValue)")
        }
    }

    func disconnect(_ clientID: BrowserIPCServer.ClientID) {
        guard let connectionID = connectionsByClient.removeValue(forKey: clientID) else { return }
        clientsByConnection.removeValue(forKey: connectionID)
        registry.disconnect(connectionID: connectionID)
    }

    private func registerConnection(
        _ object: [String: Any],
        clientID: BrowserIPCServer.ClientID
    ) -> Bool {
        guard let connectionID = object["connectionId"] as? String,
            !connectionID.isEmpty,
            BrowserKind(rawValue: object["browser"] as? String ?? "") != nil
        else { return false }
        if let previousClient = clientsByConnection[connectionID], previousClient != clientID {
            connectionsByClient.removeValue(forKey: previousClient)
        }
        clientsByConnection[connectionID] = clientID
        connectionsByClient[clientID] = connectionID
        return true
    }

    private func sendConnectionAcknowledgment(to clientID: BrowserIPCServer.ClientID) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [
                "version": BrowserProtocol.version,
                "type": "connected-result",
            ])
        else { return }
        try? send(data, to: clientID)
    }

    private func send(_ data: Data, to clientID: BrowserIPCServer.ClientID) throws {
        for server in servers {
            do {
                try server.send(data, to: clientID)
                return
            } catch {}
        }
        throw POSIXError(.ENOTCONN)
    }
}
