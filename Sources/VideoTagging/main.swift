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

    static func load() -> [URL] {
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
            return defaultFolders.filter { FileManager.default.fileExists(atPath: $0.path) }
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
            return defaultFolders.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        return uniqueFolders
    }
}

let observedFolders = Configuration.load()
let tagManager = TagManager()
let watcher = FolderWatcher(roots: observedFolders, tagManager: tagManager)
nonisolated(unsafe) let playerMonitor = PlayerMonitor(
    tagManager: tagManager, roots: observedFolders)

watcher.start()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    playerMonitor.poll()
}

print("Video tagging is watching \(observedFolders.map(\.path).joined(separator: ", ")).")
RunLoop.main.run()
