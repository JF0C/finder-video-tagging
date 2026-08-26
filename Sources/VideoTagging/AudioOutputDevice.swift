import CoreAudio
import Foundation

struct AudioOutputDevice: Codable, Equatable {
    let uid: String
    let name: String
    let transportType: UInt32

    var isAirPlay: Bool {
        transportType == kAudioDeviceTransportTypeAirPlay
    }

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }
}

enum AudioOutputDeviceError: Error {
    case coreAudio(OSStatus)
    case deviceNotFound(String)
}

enum AudioOutputDevices {
    static func all() throws -> [AudioOutputDevice] {
        let deviceIDs = try deviceIDs()
        return deviceIDs.compactMap { deviceID in
            guard isOutputDevice(deviceID),
                let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID),
                let name = stringProperty(kAudioDevicePropertyDeviceNameCFString, on: deviceID)
            else {
                return nil
            }
            return AudioOutputDevice(
                uid: uid,
                name: name,
                transportType: integerProperty(kAudioDevicePropertyTransportType, on: deviceID) ?? 0
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func current() throws -> AudioOutputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else {
            throw AudioOutputDeviceError.coreAudio(status)
        }
        return try all().first {
            $0.uid == stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID)
        }
    }

    static func setCurrent(toUID uid: String) throws {
        guard let device = try all().first(where: { $0.uid == uid }) else {
            throw AudioOutputDeviceError.deviceNotFound(uid)
        }
        let deviceID = try deviceIDs().first {
            stringProperty(kAudioDevicePropertyDeviceUID, on: $0) == device.uid
        }
        guard var deviceID else {
            throw AudioOutputDeviceError.deviceNotFound(uid)
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
        guard status == noErr else {
            throw AudioOutputDeviceError.coreAudio(status)
        }
    }

    private static func deviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32()
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr else {
            throw AudioOutputDeviceError.coreAudio(status)
        }

        var deviceIDs = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        guard status == noErr else {
            throw AudioOutputDeviceError.coreAudio(status)
        }
        return deviceIDs
    }

    private static func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32()
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr
            && size > 0
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        on deviceID: AudioDeviceID
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr,
            let value
        else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    private static func integerProperty(
        _ selector: AudioObjectPropertySelector,
        on deviceID: AudioDeviceID
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32()
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }
}
