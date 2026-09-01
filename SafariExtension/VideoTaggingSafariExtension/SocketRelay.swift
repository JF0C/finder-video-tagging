import Darwin
import Foundation

enum SocketRelayError: Error {
    case connectionFailed
    case pathTooLong
    case writeFailed
}

final class SocketRelay: @unchecked Sendable {
    static let shared = SocketRelay()

    private let path: String
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var messages: [Data] = []
    private var reconnectRequired = false

    init(path: String? = nil) {
        self.path =
            path
            ?? FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.findervideotagging.shared"
            )?.appendingPathComponent("browser.sock").path
            ?? ""
    }

    func send(_ payload: Data) throws {
        let line = payload + Data([0x0A])
        try lock.withLock {
            let descriptor = try connectedDescriptor()
            try line.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let count = Darwin.write(
                        descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                    guard count > 0 else { throw SocketRelayError.writeFailed }
                    offset += count
                }
            }
        }
    }

    func takeMessage() throws -> Data? {
        try lock.withLock {
            _ = try connectedDescriptor()
            return messages.isEmpty ? nil : messages.removeFirst()
        }
    }

    private func connectedDescriptor() throws -> Int32 {
        if reconnectRequired {
            reconnectRequired = false
            throw SocketRelayError.connectionFailed
        }
        if descriptor >= 0 { return descriptor }
        guard !path.isEmpty else { throw SocketRelayError.connectionFailed }
        let socketDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { throw SocketRelayError.connectionFailed }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else {
            close(socketDescriptor)
            throw SocketRelayError.pathTooLong
        }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: path.utf8)
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            close(socketDescriptor)
            throw SocketRelayError.connectionFailed
        }
        descriptor = socketDescriptor
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readMessages(from: socketDescriptor)
        }
        return socketDescriptor
    }

    private func readMessages(from socketDescriptor: Int32) {
        var buffer = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(socketDescriptor, &bytes, bytes.count)
            guard count > 0 else { break }
            buffer.append(contentsOf: bytes.prefix(count))
            while let newline = buffer.firstIndex(of: 0x0A) {
                let message = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard message.count <= NativeMessageAdapter.maximumMessageBytes else { break }
                lock.withLock { messages.append(message) }
            }
            if buffer.count > NativeMessageAdapter.maximumMessageBytes { break }
        }
        lock.withLock {
            if descriptor == socketDescriptor {
                descriptor = -1
                reconnectRequired = true
            }
        }
        close(socketDescriptor)
    }
}

private extension NSLock {
    func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try action()
    }
}
