import Foundation
import XCTest

@testable import FolderPickerCore
@testable import VideoTaggingCore

final class SetupConfigurationTests: XCTestCase {
    func testPickerConfigurationIsRuntimeCompatible() throws {
        let setup = SetupConfiguration(
            observedFolders: ["/videos"],
            viewedAtPercentage: 90,
            viewedSecondsBeforeEnd: 20,
            playbackResume: SetupPlaybackResumeConfiguration(
                targetOutput: SetupAudioOutputDevice(uid: "tv", name: "TV"),
                headphonesOutput: SetupAudioOutputDevice(uid: "pods", name: "AirPods"),
                rewindSeconds: 5
            )
        )
        let decoded = try JSONDecoder().decode(
            Configuration.self,
            from: JSONEncoder().encode(setup)
        )
        XCTAssertEqual(decoded.observedFolders, ["/videos"])
        XCTAssertEqual(decoded.viewedAtPercentage, 90)
        XCTAssertEqual(decoded.playbackResume?.targetOutput.uid, "tv")
        XCTAssertEqual(decoded.playbackResume?.headphonesOutput.uid, "pods")
        XCTAssertEqual(decoded.playbackResume?.rewindSeconds, 5)
    }
}
