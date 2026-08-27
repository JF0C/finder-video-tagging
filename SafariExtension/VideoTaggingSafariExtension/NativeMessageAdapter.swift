import Foundation

enum NativeMessageAdapterError: Error, Equatable {
    case invalidEnvelope
    case invalidMessage
    case oversizedMessage
    case privacyViolation
}

enum NativeMessageAction {
    case send(Data)
    case receive
}

struct NativeMessageAdapter {
    static let protocolVersion = 1
    static let maximumMessageBytes = 65_536

    func decode(_ object: Any) throws -> NativeMessageAction {
        guard let envelope = object as? [String: Any], let kind = envelope["kind"] as? String else {
            throw NativeMessageAdapterError.invalidEnvelope
        }
        if kind == "receive" { return .receive }
        guard kind == "send", let message = envelope["message"] as? [String: Any] else {
            throw NativeMessageAdapterError.invalidEnvelope
        }
        return .send(try validatedData(for: message))
    }

    func acknowledgment() -> [String: Any] {
        ["ok": true]
    }

    func received(_ data: Data?) throws -> [String: Any] {
        guard let data else { return ["message": NSNull()] }
        let message = try validatedObject(from: data)
        return ["message": message]
    }

    func failure(_ error: Error) -> [String: Any] {
        ["error": String(describing: error)]
    }

    private func validatedData(for message: [String: Any]) throws -> Data {
        try validate(message)
        let data = try JSONSerialization.data(withJSONObject: message)
        guard data.count <= Self.maximumMessageBytes else {
            throw NativeMessageAdapterError.oversizedMessage
        }
        return data
    }

    private func validatedObject(from data: Data) throws -> [String: Any] {
        guard data.count <= Self.maximumMessageBytes,
            let message = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw NativeMessageAdapterError.invalidMessage }
        try validate(message)
        return message
    }

    private func validate(_ message: [String: Any]) throws {
        guard message["version"] as? Int == Self.protocolVersion,
            message["type"] is String
        else { throw NativeMessageAdapterError.invalidMessage }
        let forbidden = Set(["url", "title"])
        guard forbidden.isDisjoint(with: message.keys.map { $0.lowercased() }) else {
            throw NativeMessageAdapterError.privacyViolation
        }
    }
}
