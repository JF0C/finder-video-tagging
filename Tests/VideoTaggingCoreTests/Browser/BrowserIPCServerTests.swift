import Darwin
import Foundation
import XCTest

@testable import VideoTaggingCore

final class BrowserIPCServerTests: XCTestCase {
    func testCreatesPrivateSocketAndExchangesMessages() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        let received = expectation(description: "received")
        let disconnected = expectation(description: "disconnected")
        let receivedMessage = ReceivedMessage()
        let server = BrowserIPCServer(
            path: path,
            onMessage: { id, data in
                receivedMessage.set(clientID: id, payload: data)
                received.fulfill()
            },
            onDisconnect: { _ in disconnected.fulfill() }
        )
        try server.start()
        defer { server.stop() }

        var attributes = try FileManager.default.attributesOfItem(atPath: path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, 0o600)
        let client = try connect(to: path)
        try write(Data(#"{"version":1}"#.utf8) + Data([0x0A]), to: client)
        wait(for: [received], timeout: 2)

        let (target, actualPayload) = receivedMessage.get()
        XCTAssertEqual(actualPayload, Data(#"{"version":1}"#.utf8))
        try server.send(Data(#"{"type":"resume-media"}"#.utf8), to: try XCTUnwrap(target))
        XCTAssertEqual(try readLine(from: client), Data(#"{"type":"resume-media"}"#.utf8))

        close(client)
        wait(for: [disconnected], timeout: 2)
        attributes = try FileManager.default.attributesOfItem(atPath: path)
        XCTAssertNotNil(attributes[.posixPermissions])
    }

    func testRejectsOversizedSendAndOverlongPath() throws {
        let server = BrowserIPCServer(path: String(repeating: "x", count: 200)) { _, _ in
        } onDisconnect: { _ in
        }

        XCTAssertThrowsError(try server.start())
        XCTAssertThrowsError(
            try server.send(
                Data(repeating: 0, count: BrowserProtocol.maximumMessageBytes + 1),
                to: UUID()
            ))
    }

    private func connect(to path: String) throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: path.utf8)
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw POSIXError(.ECONNREFUSED) }
        return descriptor
    }

    private func write(_ data: Data, to descriptor: Int32) throws {
        let result = data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
        guard result == data.count else { throw POSIXError(.EIO) }
    }

    private func readLine(from descriptor: Int32) throws -> Data {
        var result = Data()
        var byte: UInt8 = 0
        while Darwin.read(descriptor, &byte, 1) == 1, byte != 0x0A { result.append(byte) }
        return result
    }
}

private final class ReceivedMessage: @unchecked Sendable {
    private let lock = NSLock()
    private var clientID: BrowserIPCServer.ClientID?
    private var payload: Data?

    func set(clientID: BrowserIPCServer.ClientID, payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        self.clientID = clientID
        self.payload = payload
    }

    func get() -> (BrowserIPCServer.ClientID?, Data?) {
        lock.lock()
        defer { lock.unlock() }
        return (clientID, payload)
    }
}
