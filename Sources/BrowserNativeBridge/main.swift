import Darwin
import Foundation
import VideoTaggingCore

private func readExactly(_ count: Int, from handle: FileHandle) throws -> Data? {
    var data = Data()
    while data.count < count {
        let next = try handle.read(upToCount: count - data.count) ?? Data()
        if next.isEmpty { return data.isEmpty ? nil : data }
        data.append(next)
    }
    return data
}

private func forwardBrowserMessages(to socket: BridgeSocket) throws {
    let input = FileHandle.standardInput
    while let header = try readExactly(4, from: input) {
        guard header.count == 4 else { throw NativeMessageFramingError.incompleteHeader }
        let length = header.enumerated().reduce(UInt32(0)) { result, byte in
            result | UInt32(byte.element) << UInt32(byte.offset * 8)
        }
        guard length <= BrowserProtocol.maximumMessageBytes else {
            throw NativeMessageFramingError.oversizedMessage
        }
        guard let payload = try readExactly(Int(length), from: input), payload.count == length
        else {
            throw NativeMessageFramingError.incompletePayload
        }
        try socket.write(payload + Data([0x0A]))
    }
}

private func forwardSocketMessages(from socket: BridgeSocket) throws {
    let input = FileHandle(fileDescriptor: socket.descriptor, closeOnDealloc: false)
    let output = FileHandle.standardOutput
    var buffer = Data()
    while let data = try input.read(upToCount: 4096), !data.isEmpty {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let payload = buffer[..<newline]
            buffer.removeSubrange(...newline)
            try output.write(contentsOf: NativeMessageFraming.encode(Data(payload)))
        }
        guard buffer.count <= BrowserProtocol.maximumMessageBytes else {
            throw NativeMessageFramingError.oversizedMessage
        }
    }
}

let socketPath =
    CommandLine.arguments.dropFirst().first
    ?? FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/VideoTagging/browser.sock").path

do {
    let socket = try BridgeSocket(path: socketPath)
    DispatchQueue.global().async {
        do {
            try forwardSocketMessages(from: socket)
        } catch {
            fputs("Browser bridge socket read failed: \(error)\n", stderr)
        }
        exit(1)
    }
    try forwardBrowserMessages(to: socket)
} catch {
    fputs("Browser bridge failed: \(error)\n", stderr)
    exit(1)
}
