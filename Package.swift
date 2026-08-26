// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VideoTagging",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "VideoTagging",
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "FolderPicker",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
