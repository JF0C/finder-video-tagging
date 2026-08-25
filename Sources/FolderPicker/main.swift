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
guard let folders = folderPicker.chooseFolders() else {
    exit(1)
}

print(folders.map(\.path).joined(separator: "\n"))
