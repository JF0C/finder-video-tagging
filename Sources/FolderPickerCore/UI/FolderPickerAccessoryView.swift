import AppKit

extension FolderPickerController {
    func makeAccessoryView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 540))
        addFolderControls(to: view)
        addViewedControls(to: view)
        addPlaybackResumeControls(to: view)
        return view
    }

    private func addFolderControls(to view: NSView) {
        let label = NSTextField(labelWithString: "Selected folders")
        label.frame = NSRect(x: 0, y: 516, width: 520, height: 20)
        view.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 308, width: 520, height: 202))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folderPath"))
        column.width = 520
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        scrollView.documentView = tableView
        view.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 0, y: 270, width: 28, height: 28))
        configureIconButton(addButton, symbol: "plus", description: "Add folder")
        addButton.action = #selector(addFolder)
        view.addSubview(addButton)

        removeButton.frame = NSRect(x: 34, y: 270, width: 28, height: 28)
        configureIconButton(
            removeButton,
            symbol: "minus",
            description: "Remove selected folder"
        )
        removeButton.action = #selector(removeSelectedFolder)
        removeButton.isEnabled = false
        view.addSubview(removeButton)
    }

    private func configureIconButton(_ button: NSButton, symbol: String, description: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.imagePosition = .imageOnly
        button.toolTip = description
        button.target = self
    }
}
