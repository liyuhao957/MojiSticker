import Carbon
import Cocoa

class GlobalHotkey {
    struct Binding {
        let keyCode: UInt32
        let carbonModifiers: UInt32
        let handler: () -> Void
        var hotKeyRef: EventHotKeyRef?
    }

    private static let signature = OSType(0x4D4F4A49) // "MOJI"

    private var bindings: [UInt32: Binding] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private(set) var isRunning = false

    func register(keyCode: CGKeyCode, modifiers: CGEventFlags, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        bindings[id] = Binding(
            keyCode: UInt32(keyCode),
            carbonModifiers: Self.carbonModifiers(from: modifiers),
            handler: handler
        )
    }

    func start() -> Bool {
        guard !isRunning else { return true }

        if !installEventHandler() { return false }

        var allRegistered = true
        for id in bindings.keys {
            guard var binding = bindings[id] else { continue }
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.keyCode,
                binding.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                binding.hotKeyRef = ref
                bindings[id] = binding
            } else {
                NSLog("[MojiSticker] 注册快捷键失败 id=%d status=%d", id, status)
                allRegistered = false
            }
        }

        isRunning = allRegistered || bindings.values.contains { $0.hotKeyRef != nil }
        return isRunning
    }

    func stop() {
        for id in bindings.keys {
            guard var binding = bindings[id] else { continue }
            if let ref = binding.hotKeyRef {
                UnregisterEventHotKey(ref)
                binding.hotKeyRef = nil
                bindings[id] = binding
            }
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        isRunning = false
    }

    // MARK: - Private

    private func installEventHandler() -> Bool {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            refcon,
            &eventHandler
        )
        if status != noErr {
            NSLog("[MojiSticker] InstallEventHandler 失败 status=%d", status)
        }
        return status == noErr
    }

    private static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.maskCommand) { mods |= UInt32(cmdKey) }
        if flags.contains(.maskShift) { mods |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { mods |= UInt32(optionKey) }
        if flags.contains(.maskControl) { mods |= UInt32(controlKey) }
        return mods
    }
}

// C function — must be top-level, non-capturing
private func carbonHotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    // Access bindings via the callback's hotkey reference
    // Use Mirror or a helper — but simpler: store a static dispatch table
    // Actually, just dispatch on main and let the hotkey resolve
    DispatchQueue.main.async {
        hotkey.dispatch(id: hotKeyID.id)
    }
    return noErr
}

extension GlobalHotkey {
    fileprivate func dispatch(id: UInt32) {
        bindings[id]?.handler()
    }
}
