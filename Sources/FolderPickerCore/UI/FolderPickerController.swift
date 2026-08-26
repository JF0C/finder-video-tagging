import AppKit
import Foundation
import VideoTaggingCore

@MainActor
public final class FolderPickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate
{
    var folders: [URL]
    let tableView = NSTableView()
    let removeButton = NSButton()
    let percentageCheckbox = NSButton(
        checkboxWithTitle: "Percentage viewed", target: nil, action: nil)
    let percentageField = NSTextField()
    let secondsCheckbox = NSButton(
        checkboxWithTitle: "Seconds before end", target: nil, action: nil)
    let secondsField = NSTextField()
    let playbackResumeCheckbox = NSButton(
        checkboxWithTitle: "Resume video when AirPods are removed", target: nil, action: nil)
    let targetOutputPopup = NSPopUpButton()
    let headphonesOutputPopup = NSPopUpButton()
    let rewindSecondsField = NSTextField()
    let airPlayOutputs: [AudioOutputDevice]
    let bluetoothOutputs: [AudioOutputDevice]
    var continueButton: NSButton?

    public init(folders: [URL]) {
        self.folders = folders
        let outputs = (try? AudioOutputDevices.all()) ?? []
        airPlayOutputs = outputs.filter(\.isAirPlay)
        bluetoothOutputs = outputs.filter(\.isBluetooth)
    }

    public func chooseConfiguration() -> SetupConfiguration? {
        let alert = NSAlert()
        alert.messageText = "Choose folders for automatic video tagging."
        continueButton = alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = makeAccessoryView()
        updateControls()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return SetupConfiguration(
            observedFolders: folders.map(\.path),
            viewedAtPercentage: percentageCheckbox.state == .on
                ? percentageField.doubleValue : nil,
            viewedSecondsBeforeEnd: secondsCheckbox.state == .on ? secondsField.doubleValue : nil,
            playbackResume: selectedPlaybackResumeConfiguration()
        )
    }

    func selectedPlaybackResumeConfiguration() -> SetupPlaybackResumeConfiguration? {
        guard playbackResumeCheckbox.state == .on,
            let target = selectedOutput(from: targetOutputPopup, outputs: airPlayOutputs),
            let headphones = selectedOutput(
                from: headphonesOutputPopup,
                outputs: bluetoothOutputs
            )
        else { return nil }
        return SetupPlaybackResumeConfiguration(
            targetOutput: target,
            headphonesOutput: headphones,
            rewindSeconds: rewindSecondsField.doubleValue
        )
    }
}
