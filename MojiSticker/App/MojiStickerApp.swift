import SwiftUI

@main
struct MojiStickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MojiSticker", systemImage: "face.smiling") {
            Button("打开 Moji") {
                appDelegate.showSearchWindow()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        Settings {
            EmptyView()
        }
    }
}
