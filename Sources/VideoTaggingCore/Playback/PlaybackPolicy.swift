import Foundation

public enum PlaybackPolicy {
    public static func parse(_ output: String, player: Player) -> [PlaybackItem] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let values = line.split(separator: "\t", maxSplits: 3).map(String.init)
            guard values.count == 4,
                let currentTime = Double(values[1]),
                let duration = Double(values[2]),
                let isPlaying = Bool(values[3])
            else { return nil }
            return PlaybackItem(
                player: player,
                url: URL(fileURLWithPath: values[0]),
                currentTime: currentTime,
                duration: duration,
                isPlaying: isPlaying
            )
        }
    }

    public static func tag(
        for item: PlaybackItem,
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?
    ) -> ManagedTag? {
        guard item.isPlaying, item.duration > 0 else { return nil }
        let viewed =
            viewedAtPercentage.map {
                item.currentTime / item.duration >= $0 / 100
            } ?? false
            || viewedSecondsBeforeEnd.map {
                item.duration - item.currentTime <= $0
            } ?? false
        return viewed ? .viewed : .watching
    }

    public static func isObserved(_ url: URL, roots: [URL]) -> Bool {
        let path = url.standardizedFileURL.path
        return roots.contains { root in
            let rootPath = root.standardizedFileURL.path
            return path == rootPath || path.hasPrefix(rootPath + "/")
        }
    }

    public static func resumeTime(currentTime: Double, rewindSeconds: Double) -> Double {
        max(0, currentTime - rewindSeconds)
    }
}
