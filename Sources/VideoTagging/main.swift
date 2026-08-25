import Foundation

enum ManagedTag: String, CaseIterable {
    case new = "New"
    case watching = "Watching"
    case viewed = "Viewed"

    var finderColor: Int {
        switch self {
        case .new: 4
        case .watching: 5
        case .viewed: 1
        }
    }

    var finderTagEntry: String {
        finderColor == 0 ? rawValue : "\(rawValue)\n\(finderColor)"
    }
}

struct PlaybackItem {
    let url: URL
    let currentTime: Double
    let duration: Double
}

struct Configuration: Codable {
    let observedFolders: [String]
    let viewedAtPercentage: Double?
    let viewedSecondsBeforeEnd: Double?

    static func load() -> Configuration {
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let configURL =
            homeDirectory
            .appendingPathComponent("Library/Application Support/VideoTagging/config.json")
        let defaultFolders = ["Downloads", "Movies"].map {
            homeDirectory.appendingPathComponent($0, isDirectory: true)
        }

        guard let data = try? Data(contentsOf: configURL),
            let configuration = try? JSONDecoder().decode(Configuration.self, from: data)
        else {
            return Configuration(
                observedFolders: defaultFolders.filter {
                    FileManager.default.fileExists(atPath: $0.path)
                }
                .map(\.path),
                viewedAtPercentage: 85,
                viewedSecondsBeforeEnd: nil
            )
        }

        let folders = configuration.observedFolders.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        }
        let existingFolders = folders.filter { FileManager.default.fileExists(atPath: $0.path) }
        let uniqueFolders = Dictionary(grouping: existingFolders, by: \.path).compactMap {
            $0.value.first
        }

        if uniqueFolders.isEmpty {
            fputs("No configured observed folders exist; using Downloads and Movies.\n", stderr)
            return Configuration(
                observedFolders: defaultFolders.filter {
                    FileManager.default.fileExists(atPath: $0.path)
                }
                .map(\.path),
                viewedAtPercentage: configuration.viewedAtPercentage ?? 85,
                viewedSecondsBeforeEnd: configuration.viewedSecondsBeforeEnd
            )
        }

        return Configuration(
            observedFolders: uniqueFolders.map(\.path),
            viewedAtPercentage: configuration.viewedAtPercentage ?? 85,
            viewedSecondsBeforeEnd: configuration.viewedSecondsBeforeEnd
        )
    }
}

let configuration = Configuration.load()
let observedFolders = configuration.observedFolders.map {
    URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
}
let tagManager = TagManager()
let watcher = FolderWatcher(roots: observedFolders, tagManager: tagManager)
nonisolated(unsafe) let playerMonitor = PlayerMonitor(
    tagManager: tagManager,
    roots: observedFolders,
    viewedAtPercentage: configuration.viewedAtPercentage,
    viewedSecondsBeforeEnd: configuration.viewedSecondsBeforeEnd
)

watcher.start()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    playerMonitor.poll()
}

print("Video tagging is watching \(observedFolders.map(\.path).joined(separator: ", ")).")
RunLoop.main.run()
