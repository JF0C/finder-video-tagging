import CoreAudio

public struct AudioOutputDevice: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let transportType: UInt32

    public init(uid: String, name: String, transportType: UInt32) {
        self.uid = uid
        self.name = name
        self.transportType = transportType
    }

    public var isAirPlay: Bool {
        transportType == kAudioDeviceTransportTypeAirPlay
    }

    public var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }
}

public enum AudioOutputDeviceError: Error {
    case coreAudio(OSStatus)
    case deviceNotFound(String)
}
