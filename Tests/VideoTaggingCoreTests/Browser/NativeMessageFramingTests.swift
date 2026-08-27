import Foundation
import XCTest

@testable import VideoTaggingCore

final class NativeMessageFramingTests: XCTestCase {
    func testRoundTripsPayload() throws {
        let payload = Data(#"{"version":1}"#.utf8)

        XCTAssertEqual(
            try NativeMessageFraming.decode(NativeMessageFraming.encode(payload)), payload)
    }

    func testRejectsIncompleteHeaderAndPayload() {
        XCTAssertThrowsError(try NativeMessageFraming.decode(Data([1, 2, 3]))) {
            XCTAssertEqual($0 as? NativeMessageFramingError, .incompleteHeader)
        }
        XCTAssertThrowsError(try NativeMessageFraming.decode(Data([2, 0, 0, 0, 1]))) {
            XCTAssertEqual($0 as? NativeMessageFramingError, .incompletePayload)
        }
    }

    func testRejectsOversizedPayload() {
        let payload = Data(repeating: 0, count: BrowserProtocol.maximumMessageBytes + 1)

        XCTAssertThrowsError(try NativeMessageFraming.encode(payload)) {
            XCTAssertEqual($0 as? NativeMessageFramingError, .oversizedMessage)
        }
        XCTAssertThrowsError(try NativeMessageFraming.decode(Data([1, 0, 1, 0]))) {
            XCTAssertEqual($0 as? NativeMessageFramingError, .oversizedMessage)
        }
    }
}
