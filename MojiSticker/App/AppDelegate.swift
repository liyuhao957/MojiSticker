import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var searchPanel: NSPanel?
    private var globalHotkey: GlobalHotkey?
    private var ipcServer: IPCServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ClipboardService.cleanupTempFiles()
        migrateCookieStorage()
        setupStatusItem()
        setupSearchPanel()
        setupIPC()
        setupGlobalHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalHotkey?.stop()
        ipcServer?.stop()
    }

    func showSearchWindow() {
        guard let panel = searchPanel else { return }
        panel.hidesOnDeactivate = false
        positionPanel(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            panel.hidesOnDeactivate = true
        }
    }

    // MARK: - Migration

    private func migrateCookieStorage() {
        let existing = DouyinCookieManager.load()
        let (valid, _) = DouyinCookieManager.validate(existing)
        if valid { return }

        let migrated = UserDefaults.standard.bool(forKey: "legacyMigrationDone")
        if migrated { return }

        if DouyinCookieManager.migrateFromLegacy() {
            UserDefaults.standard.set(true, forKey: "legacyMigrationDone")
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: "face.smiling",
            accessibilityDescription: "MojiSticker"
        )
        button.action = #selector(statusItemClicked)
        button.target = self
    }

    @objc private func statusItemClicked() {
        showSearchWindow()
    }

    private func setupSearchPanel() {
        let panel = KeyablePanel(
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
        panel.becomesKeyOnlyIfNeeded = false

        let hostingView = NSHostingView(rootView: SearchWindow())
        panel.contentView = hostingView
        self.searchPanel = panel
    }

    private func setupGlobalHotkeys() {
        globalHotkey = GlobalHotkey()
        globalHotkey?.register(
            keyCode: 40,
            modifiers: [.maskCommand, .maskShift],
            handler: { [weak self] in self?.showSearchWindow() }
        )
        globalHotkey?.register(
            keyCode: 14,
            modifiers: [.maskCommand, .maskShift],
            handler: { NSApplication.shared.terminate(nil) }
        )

        if globalHotkey?.start() != true {
            NSLog("[MojiSticker] 全局快捷键注册失败")
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

// MARK: - KeyablePanel

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Notification.Name {
    static let mojiIPCSearch = Notification.Name("MojiIPCSearch")
}
