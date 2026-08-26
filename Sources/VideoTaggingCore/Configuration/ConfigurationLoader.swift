import Foundation

extension Configuration {
    public static func load() -> Configuration {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let configURL = home.appendingPathComponent(
            "Library/Application Support/VideoTagging/config.json")
        return resolve(
            data: try? Data(contentsOf: configURL),
            homeDirectory: home,
            fileExists: FileManager.default.fileExists(atPath:),
            report: { fputs("\($0)\n", stderr) }
        )
    }
}
