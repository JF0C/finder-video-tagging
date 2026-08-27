import Darwin
import Foundation

public final class BrowserIPCServer: @unchecked Sendable {
    public typealias ClientID = UUID

    private let path: String
    private let onMessage: @Sendable (ClientID, Data) -> Void
    private let onDisconnect: @Sendable (ClientID) -> Void
    private let lock = NSLock()
    private var listener: Int32 = -1
    private var clients: [ClientID: Int32] = [:]

    public init(
        path: String,
        onMessage: @escaping @Sendable (ClientID, Data) -> Void,
        onDisconnect: @escaping @Sendable (ClientID) -> Void
    ) {
        self.path = path
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    deinit {
        stop()
    }

    public func start() throws {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw POSIXError(.ENOTSOCK) }
        var address: sockaddr_un
        do {
            address = try socketAddress(path: path)
        } catch {
            close(descriptor)
            throw error
        }
        unlink(path)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0, chmod(path, 0o600) == 0, listen(descriptor, 8) == 0 else {
            close(descriptor)
            unlink(path)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        lock.withLock { listener = descriptor }
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.acceptClients() }
    }

    public func stop() {
        let descriptors = lock.withLock { () -> [Int32] in
            let all = Array(clients.values) + (listener >= 0 ? [listener] : [])
            clients.removeAll()
            listener = -1
            return all
        }
        descriptors.forEach { close($0) }
        unlink(path)
    }

    public func send(_ data: Data, to clientID: ClientID) throws {
        guard data.count <= BrowserProtocol.maximumMessageBytes,
            let descriptor = lock.withLock({ clients[clientID] })
        else { throw POSIXError(.EMSGSIZE) }
        var line = data
        line.append(0x0A)
        try write(line, to: descriptor)
    }

    private func acceptClients() {
        while true {
            let listener = lock.withLock { self.listener }
            guard listener >= 0 else { return }
            let descriptor = accept(listener, nil, nil)
            guard descriptor >= 0 else { continue }
            var noSignal: Int32 = 1
            setsockopt(
                descriptor,
                SOL_SOCKET,
                SO_NOSIGPIPE,
                &noSignal,
                socklen_t(MemoryLayout<Int32>.size)
            )
            var effectiveUID: uid_t = 0
            var effectiveGID: gid_t = 0
            guard getpeereid(descriptor, &effectiveUID, &effectiveGID) == 0,
                effectiveUID == geteuid()
            else {
                close(descriptor)
                continue
            }
            let clientID = ClientID()
            lock.withLock { clients[clientID] = descriptor }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.readMessages(from: descriptor, clientID: clientID)
            }
        }
    }

    private func readMessages(from descriptor: Int32, clientID: ClientID) {
        var buffer = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(descriptor, &bytes, bytes.count)
            guard count > 0 else { break }
            buffer.append(contentsOf: bytes.prefix(count))
            while let newline = buffer.firstIndex(of: 0x0A) {
                let message = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard message.count <= BrowserProtocol.maximumMessageBytes else { break }
                onMessage(clientID, message)
            }
            if buffer.count > BrowserProtocol.maximumMessageBytes { break }
        }
        _ = lock.withLock { clients.removeValue(forKey: clientID) }
        close(descriptor)
        onDisconnect(clientID)
    }

    private func socketAddress(path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: path.utf8)
        }
        return address
    }

    private func write(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(
                    descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                guard count > 0 else { throw POSIXError(.EIO) }
                offset += count
            }
        }
    }
}

extension NSLock {
    fileprivate func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
