public enum ManagedTag: String, CaseIterable, Sendable {
    case new = "New"
    case watching = "Watching"
    case viewed = "Viewed"

    public var finderColor: Int {
        switch self {
        case .new: 4
        case .watching: 5
        case .viewed: 1
        }
    }

    public var finderTagEntry: String {
        "\(rawValue)\n\(finderColor)"
    }
}
