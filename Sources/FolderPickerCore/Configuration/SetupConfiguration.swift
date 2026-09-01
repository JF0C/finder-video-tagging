import Foundation

public struct SetupConfiguration: Codable, Equatable, Sendable {
    public let observedFolders: [String]
    public let viewedAtPercentage: Double?
    public let viewedSecondsBeforeEnd: Double?
    public let playbackResume: SetupPlaybackResumeConfiguration?
    public let browserPlaybackResumeEnabled: Bool

    public init(
        observedFolders: [String],
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?,
        playbackResume: SetupPlaybackResumeConfiguration?,
        browserPlaybackResumeEnabled: Bool = false
    ) {
        self.observedFolders = observedFolders
        self.viewedAtPercentage = viewedAtPercentage
        self.viewedSecondsBeforeEnd = viewedSecondsBeforeEnd
        self.playbackResume = playbackResume
        self.browserPlaybackResumeEnabled = browserPlaybackResumeEnabled
    }
}

public struct SetupPlaybackResumeConfiguration: Codable, Equatable, Sendable {
    public let targetOutput: SetupAudioOutputDevice
    public let headphonesOutput: SetupAudioOutputDevice
    public let rewindSeconds: Double

    public init(
        targetOutput: SetupAudioOutputDevice,
        headphonesOutput: SetupAudioOutputDevice,
        rewindSeconds: Double
    ) {
        self.targetOutput = targetOutput
        self.headphonesOutput = headphonesOutput
        self.rewindSeconds = rewindSeconds
    }
}

public struct SetupAudioOutputDevice: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}
