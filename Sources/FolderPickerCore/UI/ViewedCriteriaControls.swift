import AppKit

extension FolderPickerController {
    func addViewedControls(to view: NSView) {
        let label = NSTextField(labelWithString: "Mark a video as Viewed when")
        label.frame = NSRect(x: 0, y: 240, width: 520, height: 20)
        view.addSubview(label)

        percentageCheckbox.frame = NSRect(x: 0, y: 210, width: 160, height: 24)
        configureCriteriaControl(percentageCheckbox)
        percentageCheckbox.state = .on
        view.addSubview(percentageCheckbox)

        percentageField.frame = NSRect(x: 166, y: 210, width: 56, height: 24)
        configureNumberField(percentageField, minimum: 1, maximum: 100, value: "85")
        view.addSubview(percentageField)
        addSuffix("%", frame: NSRect(x: 228, y: 213, width: 24, height: 20), to: view)

        secondsCheckbox.frame = NSRect(x: 270, y: 210, width: 160, height: 24)
        configureCriteriaControl(secondsCheckbox)
        view.addSubview(secondsCheckbox)

        secondsField.frame = NSRect(x: 436, y: 210, width: 56, height: 24)
        configureNumberField(secondsField, minimum: 1, maximum: 86_400, value: "30")
        view.addSubview(secondsField)
        addSuffix("s", frame: NSRect(x: 498, y: 213, width: 16, height: 20), to: view)
    }

    func configureCriteriaControl(_ button: NSButton) {
        button.target = self
        button.action = #selector(criteriaChanged)
    }

    func configureNumberField(
        _ field: NSTextField,
        minimum: Double,
        maximum: Double,
        value: String
    ) {
        field.formatter = numberFormatter(minimum: minimum, maximum: maximum)
        field.stringValue = value
        field.target = self
        field.action = #selector(criteriaChanged)
        field.delegate = self
    }

    func addSuffix(_ text: String, frame: NSRect, to view: NSView) {
        let suffix = NSTextField(labelWithString: text)
        suffix.frame = frame
        view.addSubview(suffix)
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
