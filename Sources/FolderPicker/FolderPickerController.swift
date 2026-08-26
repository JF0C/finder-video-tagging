import AppKit
import CoreAudio
import Foundation

struct SetupConfiguration: Codable {
    let observedFolders: [String]
    let viewedAtPercentage: Double?
    let viewedSecondsBeforeEnd: Double?
    let playbackResume: SetupPlaybackResumeConfiguration?
}

struct SetupPlaybackResumeConfiguration: Codable {
    let targetOutput: SetupAudioOutputDevice
    let headphonesOutput: SetupAudioOutputDevice
    let rewindSeconds: Double
}

struct SetupAudioOutputDevice: Codable {
    let uid: String
    let name: String
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
    private let playbackResumeCheckbox = NSButton(
        checkboxWithTitle: "Resume video when AirPods are removed", target: nil, action: nil)
    private let targetOutputPopup = NSPopUpButton()
    private let headphonesOutputPopup = NSPopUpButton()
    private let rewindSecondsField = NSTextField()
    private let airPlayOutputs: [PickerAudioOutputDevice]
    private let bluetoothOutputs: [PickerAudioOutputDevice]
    private var continueButton: NSButton?

    init(folders: [URL]) {
        self.folders = folders
        let outputs = (try? PickerAudioOutputs.all()) ?? []
        airPlayOutputs = outputs.filter(\.isAirPlay)
        bluetoothOutputs = outputs.filter(\.isBluetooth)
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
            viewedSecondsBeforeEnd: secondsCheckbox.state == .on ? secondsField.doubleValue : nil,
            playbackResume: playbackResumeCheckbox.state == .on
                ? SetupPlaybackResumeConfiguration(
                    targetOutput: selectedOutput(from: targetOutputPopup, outputs: airPlayOutputs)!,
                    headphonesOutput: selectedOutput(
                        from: headphonesOutputPopup, outputs: bluetoothOutputs)!,
                    rewindSeconds: rewindSecondsField.doubleValue
                )
                : nil
        )
    }

    private func makeAccessoryView() -> NSView {
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 540))

        let label = NSTextField(labelWithString: "Selected folders")
        label.frame = NSRect(x: 0, y: 516, width: 520, height: 20)
        accessoryView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 308, width: 520, height: 202))
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

        let addButton = NSButton(frame: NSRect(x: 0, y: 270, width: 28, height: 28))
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add folder")
        addButton.imagePosition = .imageOnly
        addButton.toolTip = "Add folder"
        addButton.target = self
        addButton.action = #selector(addFolder)
        accessoryView.addSubview(addButton)

        removeButton.frame = NSRect(x: 34, y: 270, width: 28, height: 28)
        removeButton.image = NSImage(
            systemSymbolName: "minus", accessibilityDescription: "Remove selected folder")
        removeButton.imagePosition = .imageOnly
        removeButton.toolTip = "Remove selected folder"
        removeButton.target = self
        removeButton.action = #selector(removeSelectedFolder)
        removeButton.isEnabled = false
        accessoryView.addSubview(removeButton)

        let viewedLabel = NSTextField(labelWithString: "Mark a video as Viewed when")
        viewedLabel.frame = NSRect(x: 0, y: 240, width: 520, height: 20)
        accessoryView.addSubview(viewedLabel)

        percentageCheckbox.frame = NSRect(x: 0, y: 210, width: 160, height: 24)
        percentageCheckbox.target = self
        percentageCheckbox.action = #selector(criteriaChanged)
        percentageCheckbox.state = .on
        accessoryView.addSubview(percentageCheckbox)

        percentageField.frame = NSRect(x: 166, y: 210, width: 56, height: 24)
        percentageField.formatter = numberFormatter(minimum: 1, maximum: 100)
        percentageField.stringValue = "85"
        percentageField.target = self
        percentageField.action = #selector(criteriaChanged)
        percentageField.delegate = self
        accessoryView.addSubview(percentageField)

        let percentageSuffix = NSTextField(labelWithString: "%")
        percentageSuffix.frame = NSRect(x: 228, y: 213, width: 24, height: 20)
        accessoryView.addSubview(percentageSuffix)

        secondsCheckbox.frame = NSRect(x: 270, y: 210, width: 160, height: 24)
        secondsCheckbox.target = self
        secondsCheckbox.action = #selector(criteriaChanged)
        accessoryView.addSubview(secondsCheckbox)

        secondsField.frame = NSRect(x: 436, y: 210, width: 56, height: 24)
        secondsField.formatter = numberFormatter(minimum: 1, maximum: 86_400)
        secondsField.stringValue = "30"
        secondsField.target = self
        secondsField.action = #selector(criteriaChanged)
        secondsField.delegate = self
        accessoryView.addSubview(secondsField)

        let secondsSuffix = NSTextField(labelWithString: "s")
        secondsSuffix.frame = NSRect(x: 498, y: 213, width: 16, height: 20)
        accessoryView.addSubview(secondsSuffix)

        playbackResumeCheckbox.frame = NSRect(x: 0, y: 166, width: 340, height: 24)
        playbackResumeCheckbox.target = self
        playbackResumeCheckbox.action = #selector(playbackResumeChanged)
        accessoryView.addSubview(playbackResumeCheckbox)

        let targetOutputLabel = NSTextField(labelWithString: "Apple TV / AirPlay output")
        targetOutputLabel.frame = NSRect(x: 0, y: 136, width: 200, height: 20)
        accessoryView.addSubview(targetOutputLabel)
        targetOutputPopup.frame = NSRect(x: 206, y: 132, width: 314, height: 28)
        populate(
            targetOutputPopup,
            placeholder: "Choose an available AirPlay output",
            outputs: airPlayOutputs
        )
        targetOutputPopup.target = self
        targetOutputPopup.action = #selector(playbackResumeChanged)
        accessoryView.addSubview(targetOutputPopup)

        let headphonesOutputLabel = NSTextField(labelWithString: "AirPods / Bluetooth output")
        headphonesOutputLabel.frame = NSRect(x: 0, y: 96, width: 200, height: 20)
        accessoryView.addSubview(headphonesOutputLabel)
        headphonesOutputPopup.frame = NSRect(x: 206, y: 92, width: 314, height: 28)
        populate(
            headphonesOutputPopup,
            placeholder: "Choose an available Bluetooth output",
            outputs: bluetoothOutputs
        )
        headphonesOutputPopup.target = self
        headphonesOutputPopup.action = #selector(playbackResumeChanged)
        accessoryView.addSubview(headphonesOutputPopup)

        let rewindSecondsLabel = NSTextField(labelWithString: "Rewind before resuming")
        rewindSecondsLabel.frame = NSRect(x: 0, y: 56, width: 200, height: 20)
        accessoryView.addSubview(rewindSecondsLabel)
        rewindSecondsField.frame = NSRect(x: 206, y: 52, width: 56, height: 24)
        rewindSecondsField.formatter = numberFormatter(minimum: 1, maximum: 120)
        rewindSecondsField.stringValue = "5"
        rewindSecondsField.target = self
        rewindSecondsField.action = #selector(playbackResumeChanged)
        rewindSecondsField.delegate = self
        accessoryView.addSubview(rewindSecondsField)
        let rewindSecondsSuffix = NSTextField(labelWithString: "s")
        rewindSecondsSuffix.frame = NSRect(x: 268, y: 55, width: 16, height: 20)
        accessoryView.addSubview(rewindSecondsSuffix)

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

    @objc private func playbackResumeChanged() {
        updateControls()
    }

    private func updateControls() {
        removeButton.isEnabled = tableView.selectedRow >= 0
        percentageField.isEnabled = percentageCheckbox.state == .on
        secondsField.isEnabled = secondsCheckbox.state == .on
        let playbackResumeEnabled = playbackResumeCheckbox.state == .on
        targetOutputPopup.isEnabled = playbackResumeEnabled
        headphonesOutputPopup.isEnabled = playbackResumeEnabled
        rewindSecondsField.isEnabled = playbackResumeEnabled
        let hasValidPercentage =
            percentageCheckbox.state == .on
            && (1...100).contains(percentageField.doubleValue)
        let hasValidSeconds =
            secondsCheckbox.state == .on
            && (1...86_400).contains(secondsField.doubleValue)
        let hasValidPlaybackResume =
            !playbackResumeEnabled
            || (selectedOutput(from: targetOutputPopup, outputs: airPlayOutputs) != nil
                && selectedOutput(from: headphonesOutputPopup, outputs: bluetoothOutputs) != nil
                && (1...120).contains(rewindSecondsField.doubleValue))
        continueButton?.isEnabled =
            !folders.isEmpty && (hasValidPercentage || hasValidSeconds)
            && hasValidPlaybackResume
    }

    private func populate(
        _ popup: NSPopUpButton,
        placeholder: String,
        outputs: [PickerAudioOutputDevice]
    ) {
        popup.removeAllItems()
        popup.addItem(withTitle: placeholder)
        popup.menu?.items.first?.isEnabled = false
        outputs.forEach { popup.addItem(withTitle: $0.name) }
        popup.selectItem(at: 0)
    }

    private func selectedOutput(
        from popup: NSPopUpButton,
        outputs: [PickerAudioOutputDevice]
    ) -> SetupAudioOutputDevice? {
        let index = popup.indexOfSelectedItem - 1
        guard outputs.indices.contains(index) else {
            return nil
        }
        let output = outputs[index]
        return SetupAudioOutputDevice(uid: output.uid, name: output.name)
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

private struct PickerAudioOutputDevice {
    let uid: String
    let name: String
    let transportType: UInt32

    var isAirPlay: Bool {
        transportType == kAudioDeviceTransportTypeAirPlay
    }

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }
}

private enum PickerAudioOutputs {
    static func all() throws -> [PickerAudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32()
        guard
            AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
        else {
            return []
        }
        var deviceIDs = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
                == noErr
        else {
            return []
        }

        return deviceIDs.compactMap { deviceID in
            guard isOutputDevice(deviceID),
                let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID),
                let name = stringProperty(kAudioDevicePropertyDeviceNameCFString, on: deviceID)
            else {
                return nil
            }
            return PickerAudioOutputDevice(
                uid: uid,
                name: name,
                transportType: integerProperty(kAudioDevicePropertyTransportType, on: deviceID) ?? 0
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32()
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr
            && size > 0
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        on deviceID: AudioDeviceID
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr,
            let value
        else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    private static func integerProperty(
        _ selector: AudioObjectPropertySelector,
        on deviceID: AudioDeviceID
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32()
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }
}
