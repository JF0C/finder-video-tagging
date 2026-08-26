public struct FinderTagUpdate: Equatable, Sendable {
    public let retainedEntries: [String]
    public let updatedEntries: [String]
    public let replacesManagedState: Bool
}

public enum FinderTagPolicy {
    public static func update(
        existingEntries: [String],
        with tag: ManagedTag,
        onlyIfUnmanaged: Bool
    ) -> FinderTagUpdate? {
        let managedTags = existingEntries.compactMap { entry in
            ManagedTag(rawValue: name(from: entry))
        }
        if onlyIfUnmanaged && !managedTags.isEmpty {
            return nil
        }
        let retained = existingEntries.filter { ManagedTag(rawValue: name(from: $0)) == nil }
        let updated = retained + [tag.finderTagEntry]
        guard Set(updated) != Set(existingEntries) else {
            return nil
        }
        return FinderTagUpdate(
            retainedEntries: retained,
            updatedEntries: updated,
            replacesManagedState: managedTags.contains { $0 != tag }
        )
    }

    public static func name(from entry: String) -> String {
        guard let separator = entry.lastIndex(of: "\n") else {
            return entry
        }
        return String(entry[..<separator])
    }
}
