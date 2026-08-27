import Foundation
import XCTest

@testable import VideoTaggingCore

final class BrowserProtocolTests: XCTestCase {
    func testMediaStateRoundTripsFlatWireFormat() throws {
        let original = try JSONDecoder().decode(
            BrowserMediaStateMessage.self,
            from: try json([
                "version": 1, "type": "media-state", "browser": "firefox",
                "connectionId": "connection", "tabId": 4, "frameId": 2,
                "documentId": "document", "sessionId": "session", "event": "playing",
                "isPlaying": true, "ended": false, "currentTime": 20, "duration": 100,
            ])
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserMediaStateMessage.self, from: encoded)

        XCTAssertEqual(decoded, original)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["documentId"] as? String, "document")
        XCTAssertNil(object["identity"])
    }

    func testResumeMessageRoundTripsFlatWireFormat() throws {
        let identity = BrowserMediaIdentity(
            browser: .safari,
            connectionID: "connection",
            tabID: 8,
            frameID: 3,
            documentID: "document",
            sessionID: "session"
        )
        let encoded = try JSONEncoder().encode(
            BrowserResumeMessage(identity: identity, rewindSeconds: 5)
        )

        XCTAssertEqual(
            try JSONDecoder().decode(BrowserResumeMessage.self, from: encoded),
            BrowserResumeMessage(identity: identity, rewindSeconds: 5)
        )
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}
