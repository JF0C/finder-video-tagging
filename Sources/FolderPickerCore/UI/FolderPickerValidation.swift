public struct FolderPickerValidation: Equatable, Sendable {
    public let hasFolders: Bool
    public let percentageEnabled: Bool
    public let percentage: Double
    public let secondsEnabled: Bool
    public let seconds: Double
    public let playbackResumeEnabled: Bool
    public let hasTargetOutput: Bool
    public let hasHeadphonesOutput: Bool
    public let rewindSeconds: Double

    public init(
        hasFolders: Bool,
        percentageEnabled: Bool,
        percentage: Double,
        secondsEnabled: Bool,
        seconds: Double,
        playbackResumeEnabled: Bool,
        hasTargetOutput: Bool,
        hasHeadphonesOutput: Bool,
        rewindSeconds: Double
    ) {
        self.hasFolders = hasFolders
        self.percentageEnabled = percentageEnabled
        self.percentage = percentage
        self.secondsEnabled = secondsEnabled
        self.seconds = seconds
        self.playbackResumeEnabled = playbackResumeEnabled
        self.hasTargetOutput = hasTargetOutput
        self.hasHeadphonesOutput = hasHeadphonesOutput
        self.rewindSeconds = rewindSeconds
    }

    public var canContinue: Bool {
        let validPercentage = percentageEnabled && (1...100).contains(percentage)
        let validSeconds = secondsEnabled && (1...86_400).contains(seconds)
        let validResume =
            !playbackResumeEnabled
            || (hasTargetOutput && hasHeadphonesOutput && (1...120).contains(rewindSeconds))
        return hasFolders && (validPercentage || validSeconds) && validResume
    }
}
