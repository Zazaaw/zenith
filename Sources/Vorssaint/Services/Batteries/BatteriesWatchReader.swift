// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Apple Watch's battery, asked of its iPhone through
/// libimobiledevice's companion proxy (not in the droplet).
///
/// Zenith does not link libimobiledevice: it is loaded at run time from
/// Homebrew, when it is there and the process may load it (the release
/// build's hardened runtime refuses a library signed by someone else, and
/// then Watch support is simply off).
///
/// Each value is asked on a new companion proxy client: a client that
/// answered once fails the next request (an SSL error, then a mux error).
/// Name and model come from the iPhone's cache and are kept; the level and
/// charging state come from the watch itself, whose link often needs a
/// first request to wake (`TimeoutReply`), so those are asked up to three
/// times. Read-only throughout. Everything runs on its own thread with a
/// time limit; a read that outlives it is not waited for, and no second
/// read starts while it runs.
final class BatteriesWatchReader: @unchecked Sendable {
    private typealias NewDevice = @convention(c) (UnsafeMutablePointer<OpaquePointer?>, UnsafePointer<CChar>?, Int32) -> Int32
    private typealias FreeHandle = @convention(c) (OpaquePointer?) -> Int32
    private typealias StartService = @convention(c) (OpaquePointer?, UnsafeMutablePointer<OpaquePointer?>, UnsafePointer<CChar>?) -> Int32
    private typealias Send = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Int32
    private typealias Receive = @convention(c) (OpaquePointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
    private typealias NewDict = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias NewString = @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?
    private typealias DictSet = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void
    // plist_to_xml returned void before libplist 2.3; the result is not read.
    private typealias ToXML = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, UnsafeMutablePointer<UInt32>) -> Void
    private typealias PlistFree = @convention(c) (UnsafeMutableRawPointer?) -> Void

    private struct Library {
        let newDevice: NewDevice
        let freeDevice: FreeHandle
        let startService: StartService
        let freeClient: FreeHandle
        let send: Send
        let receive: Receive
        let deviceRegistry: Receive
        let newDict: NewDict
        let newString: NewString
        let dictSet: DictSet
        let toXML: ToXML
        let plistFree: PlistFree
        let memFree: PlistFree
    }

    static let directories = ["/opt/homebrew/lib", "/usr/local/lib"]
    static let deviceLibraries = ["libimobiledevice-1.0.6.dylib", "libimobiledevice-1.0.dylib"]
    static let plistLibraries = ["libplist-2.0.dylib"]

    private static let lookupUSB: Int32 = 1 << 1
    private static let lookupNetwork: Int32 = 1 << 2
    private static let label = "zenith-batteries"
    /// The whole read, every watch on every iPhone.
    static let timeLimit: TimeInterval = 10

    private let lock = NSLock()
    private var loaded: Library?
    private var failedAt: Date?
    private var reading = false
    private var names: [String: String] = [:]

    /// Whether the library is on disk, without loading it.
    static var isInstalled: Bool {
        directories.contains { directory in
            deviceLibraries.contains { FileManager.default.fileExists(atPath: directory + "/" + $0) }
        }
    }

    /// Loads the library once; false when it is missing or refused.
    var isAvailable: Bool { library() != nil }

    /// A library that loaded is kept; one that did not is tried again at
    /// most once a minute, so installing it needs no relaunch.
    private func library() -> Library? {
        lock.lock(); defer { lock.unlock() }
        if let loaded { return loaded }
        if let failedAt, Date().timeIntervalSince(failedAt) < 60 { return nil }
        let library = Self.load()
        loaded = library
        failedAt = library == nil ? Date() : nil
        return library
    }

    private static func load() -> Library? {
        func open(_ names: [String]) -> UnsafeMutableRawPointer? {
            for directory in directories {
                for name in names {
                    let path = directory + "/" + name
                    guard FileManager.default.fileExists(atPath: path) else { continue }
                    if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) { return handle }
                }
            }
            return nil
        }
        guard let device = open(deviceLibraries) else { return nil }
        // libimobiledevice brings libplist with it; its own handle is asked
        // first and the global namespace after.
        let plist = open(plistLibraries)
        func symbol<T>(_ name: String, in handles: [UnsafeMutableRawPointer?], as type: T.Type) -> T? {
            for handle in handles.compactMap({ $0 }) {
                if let pointer = dlsym(handle, name) { return unsafeBitCast(pointer, to: type) }
            }
            return nil
        }
        let plistHandles = [plist, device]
        guard let newDevice = symbol("idevice_new_with_options", in: [device], as: NewDevice.self),
              let freeDevice = symbol("idevice_free", in: [device], as: FreeHandle.self),
              let startService = symbol("companion_proxy_client_start_service", in: [device], as: StartService.self),
              let freeClient = symbol("companion_proxy_client_free", in: [device], as: FreeHandle.self),
              let send = symbol("companion_proxy_send", in: [device], as: Send.self),
              let receive = symbol("companion_proxy_receive", in: [device], as: Receive.self),
              let deviceRegistry = symbol("companion_proxy_get_device_registry", in: [device], as: Receive.self),
              let newDict = symbol("plist_new_dict", in: plistHandles, as: NewDict.self),
              let newString = symbol("plist_new_string", in: plistHandles, as: NewString.self),
              let dictSet = symbol("plist_dict_set_item", in: plistHandles, as: DictSet.self),
              let toXML = symbol("plist_to_xml", in: plistHandles, as: ToXML.self),
              let plistFree = symbol("plist_free", in: plistHandles, as: PlistFree.self) else {
            return nil
        }
        let memFree = symbol("plist_mem_free", in: plistHandles, as: PlistFree.self) ?? { free($0) }
        return Library(newDevice: newDevice, freeDevice: freeDevice, startService: startService,
                       freeClient: freeClient, send: send, receive: receive, deviceRegistry: deviceRegistry,
                       newDict: newDict, newString: newString, dictSet: dictSet, toXML: toXML,
                       plistFree: plistFree, memFree: memFree)
    }

    /// Every watch paired with these iPhones, read within the time limit.
    /// Empty when the library is missing, a read is still running, or the
    /// watches did not answer in time.
    func read(iPhones: [BatteriesIOS.Listed]) -> [BatteryDevice] {
        guard !iPhones.isEmpty, let library = library() else { return [] }
        lock.lock()
        guard !reading else { lock.unlock(); return [] }
        reading = true
        lock.unlock()

        final class Box: @unchecked Sendable { var devices: [BatteryDevice] = [] }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let deadline = Date().addingTimeInterval(Self.timeLimit)
        let thread = Thread { [self] in
            let devices = self.readAll(iPhones: iPhones, library: library, deadline: deadline)
            self.lock.lock()
            box.devices = devices
            self.reading = false
            self.lock.unlock()
            done.signal()
        }
        thread.name = "Zenith Batteries watch"
        thread.qualityOfService = .utility
        thread.start()
        guard done.wait(timeout: .now() + Self.timeLimit + 1) == .success else { return [] }
        lock.lock(); defer { lock.unlock() }
        return box.devices
    }

    private func readAll(iPhones: [BatteriesIOS.Listed], library: Library, deadline: Date) -> [BatteryDevice] {
        var devices: [BatteryDevice] = []
        var seen = Set<String>()
        for phone in iPhones where Date() < deadline {
            var handle: OpaquePointer?
            let options = phone.network ? Self.lookupNetwork : Self.lookupUSB
            guard library.newDevice(&handle, phone.udid, options) == 0, let handle else { continue }
            defer { _ = library.freeDevice(handle) }
            for watch in registry(device: handle, library: library) where seen.insert(watch).inserted {
                guard Date() < deadline else { break }
                if let device = readWatch(watch, device: handle, library: library, deadline: deadline) {
                    devices.append(device)
                }
            }
        }
        return devices
    }

    private func registry(device: OpaquePointer, library: Library) -> [String] {
        var client: OpaquePointer?
        guard library.startService(device, &client, Self.label) == 0, let client else { return [] }
        defer { _ = library.freeClient(client) }
        var list: UnsafeMutableRawPointer?
        guard library.deviceRegistry(client, &list) == 0, let list else { return [] }
        defer { library.plistFree(list) }
        return xml(list, library: library).map(BatteriesWatch.registryUDIDs(fromXML:)) ?? []
    }

    private func readWatch(_ watch: String, device: OpaquePointer, library: Library, deadline: Date) -> BatteryDevice? {
        lock.lock()
        var name = names[watch]
        lock.unlock()
        if name == nil, case let .value(value)? = ask("DeviceName", of: watch, device: device, library: library) {
            name = value.stringValue
            if let name { lock.lock(); names[watch] = name; lock.unlock() }
        }
        let capacity = askLive("BatteryCurrentCapacity", of: watch, device: device, library: library, deadline: deadline)?.intValue
        guard capacity != nil else { return nil }
        let charging = askLive("BatteryIsCharging", of: watch, device: device, library: library, deadline: deadline)?.boolValue
        return BatteriesWatch.device(udid: watch, name: name, capacity: capacity, charging: charging)
    }

    private func askLive(_ key: String, of watch: String, device: OpaquePointer, library: Library,
                         deadline: Date) -> BatteriesWatchValue? {
        for _ in 0..<3 where Date() < deadline {
            switch ask(key, of: watch, device: device, library: library) {
            case let .value(value)?: return value
            case .timeout?: continue
            default: return nil
            }
        }
        return nil
    }

    /// One `GetValueFromRegistry` on a client of its own.
    private func ask(_ key: String, of watch: String, device: OpaquePointer, library: Library) -> BatteriesWatchReply? {
        var client: OpaquePointer?
        guard library.startService(device, &client, Self.label) == 0, let client else { return nil }
        defer { _ = library.freeClient(client) }
        guard let request = library.newDict() else { return nil }
        library.dictSet(request, "Command", library.newString("GetValueFromRegistry"))
        library.dictSet(request, "GetValueGizmoUDIDKey", library.newString(watch))
        library.dictSet(request, "GetValueKeyKey", library.newString(key))
        let sent = library.send(client, request)
        library.plistFree(request)
        guard sent == 0 else { return nil }
        var reply: UnsafeMutableRawPointer?
        guard library.receive(client, &reply) == 0, let reply else { return nil }
        defer { library.plistFree(reply) }
        return xml(reply, library: library).map { BatteriesWatch.reply(fromXML: $0, key: key) }
    }

    private func xml(_ plist: UnsafeMutableRawPointer, library: Library) -> Data? {
        var text: UnsafeMutablePointer<CChar>?
        var length: UInt32 = 0
        library.toXML(plist, &text, &length)
        guard let text else { return nil }
        defer { library.memFree(UnsafeMutableRawPointer(text)) }
        return length > 0 ? Data(bytes: text, count: Int(length)) : nil
    }
}
