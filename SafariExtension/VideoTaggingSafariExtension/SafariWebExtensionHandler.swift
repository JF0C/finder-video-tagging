import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let adapter = NativeMessageAdapter()
    private let relay = SocketRelay.shared

    func beginRequest(with context: NSExtensionContext) {
        let response: [String: Any]
        do {
            guard let item = context.inputItems.first as? NSExtensionItem,
                let object = item.userInfo?[SFExtensionMessageKey]
            else { throw NativeMessageAdapterError.invalidEnvelope }
            switch try adapter.decode(object) {
            case .send(let payload):
                try relay.send(payload)
                response = adapter.acknowledgment()
            case .receive:
                response = try adapter.received(relay.takeMessage())
            }
        } catch {
            response = adapter.failure(error)
        }

        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: response]
        context.completeRequest(returningItems: [item])
    }
}
