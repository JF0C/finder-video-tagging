import CoreAudio
import Foundation

public enum AudioOutputDevices {
    public static func all() throws -> [AudioOutputDevice] {
        try deviceIDs().compactMap { deviceID in
            guard isOutputDevice(deviceID),
                let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID),
                let name = stringProperty(kAudioDevicePropertyDeviceNameCFString, on: deviceID)
            else { return nil }
            return AudioOutputDevice(
                uid: uid,
                name: name,
                transportType: integerProperty(kAudioDevicePropertyTransportType, on: deviceID) ?? 0
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func current() throws -> AudioOutputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { throw AudioOutputDeviceError.coreAudio(status) }
        let currentUID = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID)
        return try all().first { $0.uid == currentUID }
    }

    public static func setCurrent(toUID uid: String) throws {
        guard
            var deviceID = try deviceIDs().first(where: {
                stringProperty(kAudioDevicePropertyDeviceUID, on: $0) == uid
            })
        else {
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
        guard status == noErr else { throw AudioOutputDeviceError.coreAudio(status) }
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
        guard status == noErr else { throw AudioOutputDeviceError.coreAudio(status) }
        var ids = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        guard status == noErr else { throw AudioOutputDeviceError.coreAudio(status) }
        return ids
    }

    private static func isOutputDevice(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32()
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        on id: AudioDeviceID
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
            let value
        else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func integerProperty(
        _ selector: AudioObjectPropertySelector,
        on id: AudioDeviceID
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32()
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }
}
