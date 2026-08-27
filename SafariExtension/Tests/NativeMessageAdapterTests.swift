import Foundation
import XCTest

final class NativeMessageAdapterTests: XCTestCase {
    private let adapter = NativeMessageAdapter()

    func testSendProducesProtocolPayload() throws {
        let message: [String: Any] = [
            "version": 1,
            "type": "connected",
            "browser": "safari",
            "connectionId": "connection",
        ]

        guard case .send(let data) = try adapter.decode(["kind": "send", "message": message]) else {
            return XCTFail("Expected a send action")
        }
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(decoded["browser"] as? String, "safari")
        XCTAssertEqual(decoded["version"] as? Int, 1)
    }

    func testReceiveReturnsQueuedMessage() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "type": "resume-media",
            "sessionId": "session",
        ])

        let response = try adapter.received(data)
        let message = try XCTUnwrap(response["message"] as? [String: Any])
        XCTAssertEqual(message["type"] as? String, "resume-media")
    }

    func testRejectsWrongProtocolVersion() {
        XCTAssertThrowsError(
            try adapter.decode([
                "kind": "send",
                "message": ["version": 2, "type": "connected"],
            ])
        ) { error in
            XCTAssertEqual(error as? NativeMessageAdapterError, .invalidMessage)
        }
    }

    func testRejectsBrowsingMetadata() {
        XCTAssertThrowsError(
            try adapter.decode([
                "kind": "send",
                "message": ["version": 1, "type": "media-state", "url": "https://example.com"],
            ])
        ) { error in
            XCTAssertEqual(error as? NativeMessageAdapterError, .privacyViolation)
        }
    }

    func testEmptyReceiveHasNullMessage() throws {
        XCTAssertTrue(try adapter.received(nil)["message"] is NSNull)
    }
}
