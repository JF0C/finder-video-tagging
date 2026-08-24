import AppKit
import Foundation

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

@MainActor
final class FolderPickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var folders: [URL]
    private let tableView = NSTableView()
    private let removeButton = NSButton()
    private var continueButton: NSButton?

    init(folders: [URL]) {
        self.folders = folders
    }

    func chooseFolders() -> [URL]? {
        let alert = NSAlert()
        alert.messageText = "Choose folders for automatic video tagging."
        continueButton = alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = makeAccessoryView()
        updateControls()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return folders
    }

    private func makeAccessoryView() -> NSView {
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 270))

        let label = NSTextField(labelWithString: "Selected folders")
        label.frame = NSRect(x: 0, y: 246, width: 520, height: 20)
        accessoryView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 38, width: 520, height: 202))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let folderColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("folderPath"))
        folderColumn.width = 520
        folderColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(folderColumn)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        scrollView.documentView = tableView
        accessoryView.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add folder")
        addButton.imagePosition = .imageOnly
        addButton.toolTip = "Add folder"
        addButton.target = self
        addButton.action = #selector(addFolder)
        accessoryView.addSubview(addButton)

        removeButton.frame = NSRect(x: 34, y: 0, width: 28, height: 28)
        removeButton.image = NSImage(
            systemSymbolName: "minus", accessibilityDescription: "Remove selected folder")
        removeButton.imagePosition = .imageOnly
        removeButton.toolTip = "Remove selected folder"
        removeButton.target = self
        removeButton.action = #selector(removeSelectedFolder)
        removeButton.isEnabled = false
        accessoryView.addSubview(removeButton)

        return accessoryView
    }

    @objc private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else {
            return
        }

        let existingPaths = Set(folders.map(\.path))
        folders.append(contentsOf: panel.urls.filter { !existingPaths.contains($0.path) })
        tableView.reloadData()
        updateControls()
    }

    @objc private func removeSelectedFolder() {
        let selectedRow = tableView.selectedRow
        guard folders.indices.contains(selectedRow) else {
            return
        }

        folders.remove(at: selectedRow)
        tableView.reloadData()
        let nextRow = min(selectedRow, folders.count - 1)
        if nextRow >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        }
        updateControls()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        folders.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("folderCell")
        let cell =
            (tableView.makeView(withIdentifier: identifier, owner: self) as? FolderCellView)
            ?? FolderCellView(frame: .zero)
        cell.identifier = identifier
        cell.setPath(folders[row].path)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    private func updateControls() {
        removeButton.isEnabled = tableView.selectedRow >= 0
        continueButton?.isEnabled = !folders.isEmpty
    }
}

let fileManager = FileManager.default
let initialFolders = [
    fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
    fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
].compactMap { $0 }

NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.activate(ignoringOtherApps: true)

let folderPicker = FolderPickerController(folders: initialFolders)
guard let folders = folderPicker.chooseFolders() else {
    exit(1)
}

print(folders.map(\.path).joined(separator: "\n"))
