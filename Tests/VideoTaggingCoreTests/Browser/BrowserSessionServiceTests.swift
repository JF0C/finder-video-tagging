import Darwin
import Foundation
import XCTest

@testable import VideoTaggingCore

@MainActor
final class BrowserSessionServiceTests: XCTestCase {
    func testAcceptsStateOnlyFromRegisteredConnectionAndClearsOnDisconnect() throws {
        var time: TimeInterval = 10
        let service = try makeService(now: { time })
        let client = UUID()
        service.receive(try connected(), from: client)
        service.receive(try mediaState(), from: UUID())
        XCTAssertTrue(service.freshSnapshots().isEmpty)

        service.receive(try mediaState(), from: client)
        XCTAssertEqual(service.freshSnapshots().map(\.identity.sessionID), ["session"])

        time = 11
        service.disconnect(client)
        XCTAssertTrue(service.freshSnapshots().isEmpty)
    }

    func testRejectsBrowsingMetadataAndReportsOnlyResumeStatus() throws {
        var reports: [String] = []
        let service = try makeService(report: { reports.append($0) })
        let client = UUID()
        service.receive(try connected(), from: client)
        service.receive(try mediaState(extra: ["URL": "https://example.com"]), from: client)
        XCTAssertTrue(service.freshSnapshots().isEmpty)

        service.receive(
            try json(["version": 1, "type": "resume-result", "status": "play-rejected"]),
            from: client
        )
        XCTAssertEqual(reports, ["Browser resume result: play-rejected"])
    }

    func testResumeMessageUsesFlatRoutingIdentity() throws {
        let identity = BrowserMediaIdentity(
            browser: .chrome,
            connectionID: "connection",
            tabID: 7,
            frameID: 3,
            documentID: "document",
            sessionID: "session"
        )
        let data = try JSONEncoder().encode(
            BrowserResumeMessage(identity: identity, rewindSeconds: 5)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["type"] as? String, "resume-media")
        XCTAssertEqual(object["tabId"] as? Int, 7)
        XCTAssertEqual(object["sessionId"] as? String, "session")
        XCTAssertNil(object["identity"])
    }

    func testRoutesResumeThroughRegisteredSocketClient() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        let service = try BrowserSessionService(socketPath: path, now: { 10 })
        let client = try connect(to: path)
        defer { close(client) }
        try write(try connected() + Data([0x0A]), to: client)
        try write(try mediaState() + Data([0x0A]), to: client)

        for _ in 0..<100 where service.freshSnapshots().isEmpty {
            await Task.yield()
        }
        let acknowledgment = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try readLine(from: client)) as? [String: Any]
        )
        XCTAssertEqual(acknowledgment["type"] as? String, "connected-result")
        let identity = try XCTUnwrap(service.freshSnapshots().first?.identity)
        service.resume([identity], rewindSeconds: -5)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try readLine(from: client)) as? [String: Any]
        )

        XCTAssertEqual(object["type"] as? String, "resume-media")
        XCTAssertEqual(object["sessionId"] as? String, "session")
        XCTAssertEqual(object["rewindSeconds"] as? Double, 0)
    }

    private func makeService(
        now: @escaping () -> TimeInterval = { 10 },
        report: @escaping (String) -> Void = { _ in }
    ) throws -> BrowserSessionService {
        try BrowserSessionService(
            socketPath: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).path,
            now: now,
            report: report
        )
    }

    private func connected() throws -> Data {
        try json([
            "version": 1, "type": "connected", "browser": "chrome",
            "connectionId": "connection",
        ])
    }

    private func mediaState(extra: [String: Any] = [:]) throws -> Data {
        var object: [String: Any] = [
            "version": 1, "type": "media-state", "browser": "chrome",
            "connectionId": "connection", "tabId": 7, "frameId": 0,
            "documentId": "document", "sessionId": "session", "event": "playing",
            "isPlaying": true, "ended": false, "currentTime": 20, "duration": 100,
        ]
        object.merge(extra) { _, replacement in replacement }
        return try json(object)
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
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
        let count = data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
        guard count == data.count else { throw POSIXError(.EIO) }
    }

    private func readLine(from descriptor: Int32) throws -> Data {
        var result = Data()
        var byte: UInt8 = 0
        while Darwin.read(descriptor, &byte, 1) == 1, byte != 0x0A { result.append(byte) }
        return result
    }
}
