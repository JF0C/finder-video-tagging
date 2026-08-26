import Foundation

public struct PlaybackItem: Equatable, Sendable {
    public let player: Player
    public let url: URL
    public let currentTime: Double
    public let duration: Double
    public let isPlaying: Bool

    public init(
        player: Player,
        url: URL,
        currentTime: Double,
        duration: Double,
        isPlaying: Bool
    ) {
        self.player = player
        self.url = url
        self.currentTime = currentTime
        self.duration = duration
        self.isPlaying = isPlaying
    }
}

public enum Player: Equatable, Sendable {
    case vlc
    case quickTime
}
