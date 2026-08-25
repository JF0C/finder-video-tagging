import Darwin
import Foundation

final class TagManager: @unchecked Sendable {
    private let finderInfoAttribute = "com.apple.FinderInfo"
    private let finderInfoColorFlagsOffset = 9
    private let finderInfoColorFlagsMask: UInt8 = 0x0E
    private let conflictingColorTagNames: Set<String> = [
        "Blau", "Grün", "Gelb", "Grau", "Green", "Yellow", "Gray",
    ]

    func apply(_ managedTag: ManagedTag, to url: URL, onlyIfUnmanaged: Bool = false) {
        guard isSupportedMedia(url), FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let existingEntries = try readFinderTagEntries(from: url)
            let hasManagedTag = existingEntries.contains {
                ManagedTag(rawValue: finderTagName(from: $0)) != nil
            }

            if onlyIfUnmanaged && hasManagedTag {
                removeConflictingColorTags(from: existingEntries, url: url)
                try clearLegacyFinderColor(from: url)
                return
            }

            let retainedTags =
                existingEntries.filter {
                    let tagName = finderTagName(from: $0)
                    return ManagedTag(rawValue: tagName) == nil
                        && !conflictingColorTagNames.contains(tagName)
                }
            let updatedTags = retainedTags + [managedTag.finderTagEntry]
            if Set(updatedTags) != Set(existingEntries) {
                let replacesExistingState = existingEntries.contains {
                    guard let existingTag = ManagedTag(rawValue: finderTagName(from: $0)) else {
                        return false
                    }
                    return existingTag != managedTag
                }
                if replacesExistingState {
                    try writeFinderTags(retainedTags, to: url)
                }
                try writeFinderTags(updatedTags, to: url)
                print("Tagged \(url.path) as \(managedTag.rawValue)")
            }
            try clearLegacyFinderColor(from: url)
        } catch {
            fputs("Could not tag \(url.path): \(error)\n", stderr)
        }
    }

    func isSupportedMedia(_ url: URL) -> Bool {
        ["mkv", "mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    private func readFinderTagEntries(from url: URL) throws -> [String] {
        let attribute = "com.apple.metadata:_kMDItemUserTags"
        let length = getxattr(url.path, attribute, nil, 0, 0, 0)

        guard length >= 0 else {
            if errno == ENOATTR {
                return []
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(url.path, attribute, bytes.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
            ?? []
    }

    private func finderTagName(from entry: String) -> String {
        guard let separator = entry.lastIndex(of: "\n") else {
            return entry
        }
        return String(entry[..<separator])
    }

    private func removeConflictingColorTags(from entries: [String], url: URL) {
        let updatedEntries = entries.filter {
            !conflictingColorTagNames.contains(finderTagName(from: $0))
        }
        guard Set(updatedEntries) != Set(entries) else {
            return
        }

        do {
            try writeFinderTags(updatedEntries, to: url)
            print("Removed conflicting color tags from \(url.path)")
        } catch {
            fputs("Could not clean up tags for \(url.path): \(error)\n", stderr)
        }
    }

    private func clearLegacyFinderColor(from url: URL) throws {
        let length = getxattr(url.path, finderInfoAttribute, nil, 0, 0, 0)

        guard length >= 0 else {
            if errno == ENOATTR {
                return
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard length > finderInfoColorFlagsOffset else {
            return
        }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(url.path, finderInfoAttribute, bytes.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let updatedFlags = data[finderInfoColorFlagsOffset] & ~finderInfoColorFlagsMask
        guard updatedFlags != data[finderInfoColorFlagsOffset] else {
            return
        }
        data[finderInfoColorFlagsOffset] = updatedFlags

        let writeResult = data.withUnsafeBytes { bytes in
            setxattr(
                url.path,
                finderInfoAttribute,
                bytes.baseAddress,
                bytes.count,
                0,
                0
            )
        }
        guard writeResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func writeFinderTags(_ entries: [String], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: entries,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { bytes in
            setxattr(
                url.path,
                "com.apple.metadata:_kMDItemUserTags",
                bytes.baseAddress,
                bytes.count,
                0,
                0
            )
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
