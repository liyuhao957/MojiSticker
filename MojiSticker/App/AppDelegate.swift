import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var searchPanel: NSPanel?
    private var globalHotkey: GlobalHotkey?
    private var ipcServer: IPCServer?
    private var watchdogTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupSearchPanel()
        setupIPC()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupGlobalHotkeys()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalHotkey?.stop()
        watchdogTimer?.invalidate()
        ipcServer?.stop()
    }

    func showSearchWindow() {
        guard let panel = searchPanel else { return }
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: - Setup

    private func setupSearchPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let hostingView = NSHostingView(rootView: SearchWindow())
        panel.contentView = hostingView
        self.searchPanel = panel
    }

    private func setupGlobalHotkeys() {
        globalHotkey = GlobalHotkey()
        // Cmd+Shift+K (keyCode 40)
        globalHotkey?.register(
            keyCode: 40,
            modifiers: [.maskCommand, .maskShift],
            handler: { [weak self] in self?.showSearchWindow() }
        )
        // Cmd+Shift+E (keyCode 14)
        globalHotkey?.register(
            keyCode: 14,
            modifiers: [.maskCommand, .maskShift],
            handler: { NSApplication.shared.terminate(nil) }
        )
        _ = globalHotkey?.start()

        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let hotkey = self?.globalHotkey else { return }
            if !hotkey.isRunning { _ = hotkey.start() }
            else if !hotkey.isTapEnabled { hotkey.ensureEnabled() }
        }
    }

    private func setupIPC() {
        ipcServer = IPCServer()
        ipcServer?.onCommand = { [weak self] command, keyword in
            guard command == "OPEN_SEARCH" else { return }
            self?.showSearchWindow()
            if let keyword {
                NotificationCenter.default.post(
                    name: .mojiIPCSearch, object: keyword
                )
            }
        }
        ipcServer?.start()
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - panel.frame.width - 20
        let y = screenFrame.maxY - panel.frame.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

extension Notification.Name {
    static let mojiIPCSearch = Notification.Name("MojiIPCSearch")
}
