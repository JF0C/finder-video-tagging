import AppKit
import SafariServices

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let button = NSButton(
            title: "Open Safari Extensions Settings", target: self, action: #selector(openSettings))
        button.bezelStyle = .rounded
        let label = NSTextField(
            labelWithString: "Enable Video Tagging for Safari, then allow access to websites.")
        label.alignment = .center

        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 150),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Video Tagging for Safari"
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    @objc private func openSettings() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: "com.findervideotagging.safari.extension"
        ) { error in
            if let error {
                NSAlert(error: error).runModal()
            }
        }
    }
}
