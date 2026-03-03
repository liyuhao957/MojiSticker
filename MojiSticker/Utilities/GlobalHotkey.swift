import Foundation
import Cocoa

class GlobalHotkey {
    struct Binding {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags
        let handler: () -> Void
    }

    private var bindings: [Binding] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?

    private(set) var isRunning = false
    private(set) var isTapEnabled = false

    func register(keyCode: CGKeyCode, modifiers: CGEventFlags, handler: @escaping () -> Void) {
        bindings.append(Binding(keyCode: keyCode, modifiers: modifiers, handler: handler))
    }

    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = hotkey.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    hotkey.isTapEnabled = true
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .keyDown else { return Unmanaged.passRetained(event) }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            for binding in hotkey.bindings {
                if keyCode == binding.keyCode && flags.contains(binding.modifiers) {
                    DispatchQueue.main.async { binding.handler() }
                }
            }
            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else { return false }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.isTapEnabled = true
        self.isRunning = true

        thread = Thread { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
            self.isRunning = false
        }
        thread?.start()
        return true
    }

    func ensureEnabled() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        isTapEnabled = true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopSourceInvalidate(source)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        isTapEnabled = false
    }
}
