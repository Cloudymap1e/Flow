#if os(macOS)
import Foundation
import CoreAudio

enum BuiltInAudioDevice {
    private static var cachedUID: String?

    static func playbackIdentifier() -> String? {
        if let cachedUID {
            return cachedUID
        }
        guard let uid = queryBuiltInOutputUID() else {
            return nil
        }
        cachedUID = uid
        return uid
    }

    static func invalidateCache() {
        cachedUID = nil
    }

    private static func queryBuiltInOutputUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard
        )
        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr else {
            return nil
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &devices) == noErr else {
            return nil
        }

        for device in devices {
            guard isBuiltIn(device), hasOutputChannels(device) else { continue }
            if let uid = deviceUID(device) {
                return uid
            }
        }
        return nil
    }

    private static func isBuiltIn(_ device: AudioDeviceID) -> Bool {
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard
        )
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, &transportType)
        guard status == noErr else { return false }
        return transportType == kAudioDeviceTransportTypeBuiltIn
    }

    private static func hasOutputChannels(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementWildcard
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        guard AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, rawPointer) == noErr else {
            return false
        }

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var channelCount = 0
        for buffer in buffers {
            channelCount += Int(buffer.mNumberChannels)
        }
        return channelCount > 0
    }

    private static func deviceUID(_ device: AudioDeviceID) -> String? {
        var cfUID: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard
        )
        let status: OSStatus = withUnsafeMutablePointer(to: &cfUID) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr, let cfUID else {
            return nil
        }
        return cfUID as String
    }
}
#endif
