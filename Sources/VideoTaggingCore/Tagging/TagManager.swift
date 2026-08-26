import Darwin
import Foundation

public final class TagManager: @unchecked Sendable {
    public init() {}

    public func apply(_ tag: ManagedTag, to url: URL, onlyIfUnmanaged: Bool = false) {
        guard isSupportedMedia(url), FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            let existing = try readFinderTags(from: url)
            guard
                let update = FinderTagPolicy.update(
                    existingEntries: existing,
                    with: tag,
                    onlyIfUnmanaged: onlyIfUnmanaged
                )
            else {
                return
            }
            if update.replacesManagedState {
                try writeFinderTags(update.retainedEntries, to: url)
            }
            try writeFinderTags(update.updatedEntries, to: url)
            print("Tagged \(url.path) as \(tag.rawValue)")
        } catch {
            fputs("Could not tag \(url.path): \(error)\n", stderr)
        }
    }

    public func isSupportedMedia(_ url: URL) -> Bool {
        Self.isSupportedMedia(url)
    }

    public static func isSupportedMedia(_ url: URL) -> Bool {
        ["mkv", "mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    private func readFinderTags(from url: URL) throws -> [String] {
        let attribute = "com.apple.metadata:_kMDItemUserTags"
        let length = getxattr(url.path, attribute, nil, 0, 0, 0)
        guard length >= 0 else {
            if errno == ENOATTR { return [] }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            getxattr(url.path, attribute, $0.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
            ?? []
    }

    private func writeFinderTags(_ entries: [String], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: entries,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes {
            setxattr(
                url.path,
                "com.apple.metadata:_kMDItemUserTags",
                $0.baseAddress,
                $0.count,
                0,
                0
            )
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
