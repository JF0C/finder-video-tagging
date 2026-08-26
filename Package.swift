// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VideoTagging",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "VideoTaggingCore",
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "VideoTagging",
            dependencies: ["VideoTaggingCore"]
        ),
        .target(
            name: "FolderPickerCore",
            dependencies: ["VideoTaggingCore"],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .executableTarget(
            name: "FolderPicker",
            dependencies: ["FolderPickerCore"]
        ),
        .testTarget(
            name: "VideoTaggingCoreTests",
            dependencies: ["VideoTaggingCore"]
        ),
        .testTarget(
            name: "FolderPickerCoreTests",
            dependencies: ["FolderPickerCore", "VideoTaggingCore"]
        ),
    ]
)
