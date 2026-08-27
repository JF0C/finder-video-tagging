import Darwin
import Foundation

enum BridgeSocketError: Error {
    case pathTooLong
    case connectionFailed
    case writeFailed
}

final class BridgeSocket: @unchecked Sendable {
    let descriptor: Int32

    init(path: String) throws {
        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw BridgeSocketError.connectionFailed }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else {
            close(descriptor)
            throw BridgeSocketError.pathTooLong
        }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: path.utf8)
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            close(descriptor)
            throw BridgeSocketError.connectionFailed
        }
    }

    deinit {
        close(descriptor)
    }

    func write(_ data: Data) throws {
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(
                    descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                guard count > 0 else { throw BridgeSocketError.writeFailed }
                offset += count
            }
        }
    }
}
