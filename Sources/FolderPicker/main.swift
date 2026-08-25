import AppKit
import Foundation

let fileManager = FileManager.default
let initialFolders = [
    fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
    fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
].compactMap { $0 }

NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.activate(ignoringOtherApps: true)

let folderPicker = FolderPickerController(folders: initialFolders)
guard let configuration = folderPicker.chooseConfiguration() else {
    exit(1)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
guard let data = try? encoder.encode(configuration),
    let output = String(data: data, encoding: .utf8)
else {
    exit(1)
}
print(output)
