import AppKit
import VideoTaggingCore

extension FolderPickerController {
    func addPlaybackResumeControls(to view: NSView) {
        playbackResumeCheckbox.frame = NSRect(x: 0, y: 166, width: 340, height: 24)
        playbackResumeCheckbox.target = self
        playbackResumeCheckbox.action = #selector(playbackResumeChanged)
        view.addSubview(playbackResumeCheckbox)

        addOutputControl(
            label: "Apple TV / AirPlay output",
            popup: targetOutputPopup,
            placeholder: "Choose an available AirPlay output",
            outputs: airPlayOutputs,
            y: 132,
            to: view
        )
        addOutputControl(
            label: "AirPods / Bluetooth output",
            popup: headphonesOutputPopup,
            placeholder: "Choose an available Bluetooth output",
            outputs: bluetoothOutputs,
            y: 92,
            to: view
        )

        let rewindLabel = NSTextField(labelWithString: "Rewind before resuming")
        rewindLabel.frame = NSRect(x: 0, y: 56, width: 200, height: 20)
        view.addSubview(rewindLabel)
        rewindSecondsField.frame = NSRect(x: 206, y: 52, width: 56, height: 24)
        configureNumberField(rewindSecondsField, minimum: 1, maximum: 120, value: "5")
        rewindSecondsField.action = #selector(playbackResumeChanged)
        view.addSubview(rewindSecondsField)
        addSuffix("s", frame: NSRect(x: 268, y: 55, width: 16, height: 20), to: view)
    }

    private func addOutputControl(
        label: String,
        popup: NSPopUpButton,
        placeholder: String,
        outputs: [AudioOutputDevice],
        y: CGFloat,
        to view: NSView
    ) {
        let text = NSTextField(labelWithString: label)
        text.frame = NSRect(x: 0, y: y + 4, width: 200, height: 20)
        view.addSubview(text)
        popup.frame = NSRect(x: 206, y: y, width: 314, height: 28)
        populate(popup, placeholder: placeholder, outputs: outputs)
        popup.target = self
        popup.action = #selector(playbackResumeChanged)
        view.addSubview(popup)
    }

    private func populate(
        _ popup: NSPopUpButton,
        placeholder: String,
        outputs: [AudioOutputDevice]
    ) {
        popup.removeAllItems()
        popup.addItem(withTitle: placeholder)
        popup.menu?.items.first?.isEnabled = false
        outputs.forEach { popup.addItem(withTitle: $0.name) }
        popup.selectItem(at: 0)
    }
}
