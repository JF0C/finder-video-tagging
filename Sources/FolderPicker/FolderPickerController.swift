import AppKit
import Foundation

struct SetupConfiguration: Codable {
    let observedFolders: [String]
    let viewedAtPercentage: Double?
    let viewedSecondsBeforeEnd: Double?
}

@MainActor
final class FolderPickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate
{
    private var folders: [URL]
    private let tableView = NSTableView()
    private let removeButton = NSButton()
    private let percentageCheckbox = NSButton(
        checkboxWithTitle: "Percentage viewed", target: nil, action: nil)
    private let percentageField = NSTextField()
    private let secondsCheckbox = NSButton(
        checkboxWithTitle: "Seconds before end", target: nil, action: nil)
    private let secondsField = NSTextField()
    private var continueButton: NSButton?

    init(folders: [URL]) {
        self.folders = folders
    }

    func chooseConfiguration() -> SetupConfiguration? {
        let alert = NSAlert()
        alert.messageText = "Choose folders for automatic video tagging."
        continueButton = alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = makeAccessoryView()
        updateControls()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return SetupConfiguration(
            observedFolders: folders.map(\.path),
            viewedAtPercentage: percentageCheckbox.state == .on ? percentageField.doubleValue : nil,
            viewedSecondsBeforeEnd: secondsCheckbox.state == .on ? secondsField.doubleValue : nil
        )
    }

    private func makeAccessoryView() -> NSView {
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 366))

        let label = NSTextField(labelWithString: "Selected folders")
        label.frame = NSRect(x: 0, y: 342, width: 520, height: 20)
        accessoryView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 134, width: 520, height: 202))
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

        let addButton = NSButton(frame: NSRect(x: 0, y: 96, width: 28, height: 28))
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add folder")
        addButton.imagePosition = .imageOnly
        addButton.toolTip = "Add folder"
        addButton.target = self
        addButton.action = #selector(addFolder)
        accessoryView.addSubview(addButton)

        removeButton.frame = NSRect(x: 34, y: 96, width: 28, height: 28)
        removeButton.image = NSImage(
            systemSymbolName: "minus", accessibilityDescription: "Remove selected folder")
        removeButton.imagePosition = .imageOnly
        removeButton.toolTip = "Remove selected folder"
        removeButton.target = self
        removeButton.action = #selector(removeSelectedFolder)
        removeButton.isEnabled = false
        accessoryView.addSubview(removeButton)

        let viewedLabel = NSTextField(labelWithString: "Mark a video as Viewed when")
        viewedLabel.frame = NSRect(x: 0, y: 66, width: 520, height: 20)
        accessoryView.addSubview(viewedLabel)

        percentageCheckbox.frame = NSRect(x: 0, y: 36, width: 160, height: 24)
        percentageCheckbox.target = self
        percentageCheckbox.action = #selector(criteriaChanged)
        percentageCheckbox.state = .on
        accessoryView.addSubview(percentageCheckbox)

        percentageField.frame = NSRect(x: 166, y: 36, width: 56, height: 24)
        percentageField.formatter = numberFormatter(minimum: 1, maximum: 100)
        percentageField.stringValue = "85"
        percentageField.target = self
        percentageField.action = #selector(criteriaChanged)
        percentageField.delegate = self
        accessoryView.addSubview(percentageField)

        let percentageSuffix = NSTextField(labelWithString: "%")
        percentageSuffix.frame = NSRect(x: 228, y: 39, width: 24, height: 20)
        accessoryView.addSubview(percentageSuffix)

        secondsCheckbox.frame = NSRect(x: 270, y: 36, width: 160, height: 24)
        secondsCheckbox.target = self
        secondsCheckbox.action = #selector(criteriaChanged)
        accessoryView.addSubview(secondsCheckbox)

        secondsField.frame = NSRect(x: 436, y: 36, width: 56, height: 24)
        secondsField.formatter = numberFormatter(minimum: 1, maximum: 86_400)
        secondsField.stringValue = "30"
        secondsField.target = self
        secondsField.action = #selector(criteriaChanged)
        secondsField.delegate = self
        accessoryView.addSubview(secondsField)

        let secondsSuffix = NSTextField(labelWithString: "s")
        secondsSuffix.frame = NSRect(x: 498, y: 39, width: 16, height: 20)
        accessoryView.addSubview(secondsSuffix)

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

    func controlTextDidChange(_ notification: Notification) {
        updateControls()
    }

    @objc private func criteriaChanged() {
        updateControls()
    }

    private func updateControls() {
        removeButton.isEnabled = tableView.selectedRow >= 0
        percentageField.isEnabled = percentageCheckbox.state == .on
        secondsField.isEnabled = secondsCheckbox.state == .on
        let hasValidPercentage =
            percentageCheckbox.state == .on
            && (1...100).contains(percentageField.doubleValue)
        let hasValidSeconds =
            secondsCheckbox.state == .on
            && (1...86_400).contains(secondsField.doubleValue)
        continueButton?.isEnabled = !folders.isEmpty && (hasValidPercentage || hasValidSeconds)
    }

    private func numberFormatter(minimum: Double, maximum: Double) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: minimum)
        formatter.maximum = NSNumber(value: maximum)
        return formatter
    }
}
