import AppKit

@MainActor
final class FolderCellView: NSTableCellView {
    private let pathLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(pathLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        pathLabel.frame = bounds.insetBy(dx: 6, dy: 0)
    }

    func setPath(_ path: String) {
        pathLabel.stringValue = path
    }
}
