import Foundation

public struct PlaybackResumeConfiguration: Codable, Equatable, Sendable {
    public let targetOutput: ConfiguredAudioOutput
    public let headphonesOutput: ConfiguredAudioOutput
    public let rewindSeconds: Double

    public init(
        targetOutput: ConfiguredAudioOutput,
        headphonesOutput: ConfiguredAudioOutput,
        rewindSeconds: Double
    ) {
        self.targetOutput = targetOutput
        self.headphonesOutput = headphonesOutput
        self.rewindSeconds = rewindSeconds
    }
}

public struct ConfiguredAudioOutput: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public let observedFolders: [String]
    public let viewedAtPercentage: Double?
    public let viewedSecondsBeforeEnd: Double?
    public let playbackResume: PlaybackResumeConfiguration?

    public init(
        observedFolders: [String],
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?,
        playbackResume: PlaybackResumeConfiguration?
    ) {
        self.observedFolders = observedFolders
        self.viewedAtPercentage = viewedAtPercentage
        self.viewedSecondsBeforeEnd = viewedSecondsBeforeEnd
        self.playbackResume = playbackResume
    }

    public static func resolve(
        data: Data?,
        homeDirectory: URL,
        fileExists: (String) -> Bool,
        report: (String) -> Void = { _ in }
    ) -> Configuration {
        let defaults = ["Downloads", "Movies"].map {
            homeDirectory.appendingPathComponent($0, isDirectory: true).standardizedFileURL
        }
        let availableDefaults = defaults.filter { fileExists($0.path) }.map(\.path)
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self(
                observedFolders: availableDefaults,
                viewedAtPercentage: 85,
                viewedSecondsBeforeEnd: nil,
                playbackResume: nil
            )
        }

        var seen = Set<String>()
        let folders = decoded.observedFolders
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path }
            .filter { fileExists($0) && seen.insert($0).inserted }
        if folders.isEmpty {
            report("No configured observed folders exist; using Downloads and Movies.")
        }
        return Self(
            observedFolders: folders.isEmpty ? availableDefaults : folders,
            viewedAtPercentage: decoded.viewedAtPercentage ?? 85,
            viewedSecondsBeforeEnd: decoded.viewedSecondsBeforeEnd,
            playbackResume: decoded.playbackResume
        )
    }
}
