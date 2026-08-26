import AppKit
import VideoTaggingCore

extension FolderPickerController {
    @objc func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let existingPaths = Set(folders.map(\.path))
        folders.append(contentsOf: panel.urls.filter { !existingPaths.contains($0.path) })
        tableView.reloadData()
        updateControls()
    }

    @objc func removeSelectedFolder() {
        let selectedRow = tableView.selectedRow
        guard folders.indices.contains(selectedRow) else { return }
        folders.remove(at: selectedRow)
        tableView.reloadData()
        let nextRow = min(selectedRow, folders.count - 1)
        if nextRow >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        }
        updateControls()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        folders.count
    }

    public func tableView(
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

    public func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    public func controlTextDidChange(_ notification: Notification) {
        updateControls()
    }

    @objc func criteriaChanged() {
        updateControls()
    }

    @objc func playbackResumeChanged() {
        updateControls()
    }

    func updateControls() {
        removeButton.isEnabled = tableView.selectedRow >= 0
        percentageField.isEnabled = percentageCheckbox.state == .on
        secondsField.isEnabled = secondsCheckbox.state == .on
        let resumeEnabled = playbackResumeCheckbox.state == .on
        targetOutputPopup.isEnabled = resumeEnabled
        headphonesOutputPopup.isEnabled = resumeEnabled
        rewindSecondsField.isEnabled = resumeEnabled
        continueButton?.isEnabled = validation().canContinue
    }

    func validation() -> FolderPickerValidation {
        FolderPickerValidation(
            hasFolders: !folders.isEmpty,
            percentageEnabled: percentageCheckbox.state == .on,
            percentage: percentageField.doubleValue,
            secondsEnabled: secondsCheckbox.state == .on,
            seconds: secondsField.doubleValue,
            playbackResumeEnabled: playbackResumeCheckbox.state == .on,
            hasTargetOutput: selectedOutput(from: targetOutputPopup, outputs: airPlayOutputs)
                != nil,
            hasHeadphonesOutput: selectedOutput(
                from: headphonesOutputPopup,
                outputs: bluetoothOutputs
            ) != nil,
            rewindSeconds: rewindSecondsField.doubleValue
        )
    }

    func selectedOutput(
        from popup: NSPopUpButton,
        outputs: [AudioOutputDevice]
    ) -> SetupAudioOutputDevice? {
        let index = popup.indexOfSelectedItem - 1
        guard outputs.indices.contains(index) else { return nil }
        return SetupAudioOutputDevice(uid: outputs[index].uid, name: outputs[index].name)
    }
}
