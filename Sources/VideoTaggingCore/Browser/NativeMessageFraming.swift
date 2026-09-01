import Foundation

public enum NativeMessageFramingError: Error, Equatable {
    case incompleteHeader
    case incompletePayload
    case oversizedMessage
}

public enum NativeMessageFraming {
    public static func encode(_ payload: Data) throws -> Data {
        guard payload.count <= BrowserProtocol.maximumMessageBytes else {
            throw NativeMessageFramingError.oversizedMessage
        }
        var length = UInt32(payload.count).littleEndian
        var framed = withUnsafeBytes(of: &length) { Data($0) }
        framed.append(payload)
        return framed
    }

    public static func decode(_ frame: Data) throws -> Data {
        guard frame.count >= MemoryLayout<UInt32>.size else {
            throw NativeMessageFramingError.incompleteHeader
        }
        let length = frame.prefix(4).enumerated().reduce(UInt32(0)) { result, byte in
            result | UInt32(byte.element) << UInt32(byte.offset * 8)
        }
        guard length <= BrowserProtocol.maximumMessageBytes else {
            throw NativeMessageFramingError.oversizedMessage
        }
        guard frame.count == Int(length) + 4 else {
            throw NativeMessageFramingError.incompletePayload
        }
        return frame.dropFirst(4)
    }
}
