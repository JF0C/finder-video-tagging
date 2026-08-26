import XCTest

@testable import FolderPickerCore

final class FolderPickerValidationTests: XCTestCase {
    func testValidPercentageCriterionAllowsContinuation() {
        XCTAssertTrue(validation(percentageEnabled: true, percentage: 85).canContinue)
    }

    func testCriterionAndFolderAreRequired() {
        XCTAssertFalse(validation().canContinue)
        XCTAssertFalse(
            validation(
                hasFolders: false, percentageEnabled: true, percentage: 85
            ).canContinue)
        XCTAssertFalse(validation(percentageEnabled: true, percentage: 101).canContinue)
    }

    func testSecondsCriterionAcceptsItsBoundaries() {
        XCTAssertTrue(validation(secondsEnabled: true, seconds: 1).canContinue)
        XCTAssertTrue(validation(secondsEnabled: true, seconds: 86_400).canContinue)
        XCTAssertFalse(validation(secondsEnabled: true, seconds: 86_401).canContinue)
    }

    func testPlaybackResumeRequiresOutputsAndValidRewind() {
        XCTAssertFalse(
            validation(
                percentageEnabled: true,
                percentage: 85,
                playbackResumeEnabled: true
            ).canContinue)
        XCTAssertTrue(
            validation(
                percentageEnabled: true,
                percentage: 85,
                playbackResumeEnabled: true,
                hasTargetOutput: true,
                hasHeadphonesOutput: true,
                rewindSeconds: 5
            ).canContinue)
    }

    private func validation(
        hasFolders: Bool = true,
        percentageEnabled: Bool = false,
        percentage: Double = 0,
        secondsEnabled: Bool = false,
        seconds: Double = 0,
        playbackResumeEnabled: Bool = false,
        hasTargetOutput: Bool = false,
        hasHeadphonesOutput: Bool = false,
        rewindSeconds: Double = 0
    ) -> FolderPickerValidation {
        FolderPickerValidation(
            hasFolders: hasFolders,
            percentageEnabled: percentageEnabled,
            percentage: percentage,
            secondsEnabled: secondsEnabled,
            seconds: seconds,
            playbackResumeEnabled: playbackResumeEnabled,
            hasTargetOutput: hasTargetOutput,
            hasHeadphonesOutput: hasHeadphonesOutput,
            rewindSeconds: rewindSeconds
        )
    }
}
