import CoreAudio
import XCTest

@testable import VideoTaggingCore

final class AudioOutputDeviceTests: XCTestCase {
    func testClassifiesAudioTransportTypes() {
        let airPlay = AudioOutputDevice(
            uid: "airplay",
            name: "TV",
            transportType: kAudioDeviceTransportTypeAirPlay
        )
        let bluetooth = AudioOutputDevice(
            uid: "bluetooth",
            name: "Headphones",
            transportType: kAudioDeviceTransportTypeBluetooth
        )
        XCTAssertTrue(airPlay.isAirPlay)
        XCTAssertFalse(airPlay.isBluetooth)
        XCTAssertTrue(bluetooth.isBluetooth)
        XCTAssertFalse(bluetooth.isAirPlay)
    }
}
