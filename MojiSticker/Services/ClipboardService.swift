import AppKit

struct ClipboardService {
    static func copyStatic(pngData: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pngData, forType: .png)
    }

    static func copyAnimatedGIF(data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .init("com.compuserve.gif"))
        if let tempURL = writeTempFile(data: data, ext: "gif") {
            pb.setString(tempURL.absoluteString, forType: .fileURL)
        }
    }

    static func copyAnimatedWebP(data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .init("org.webmproject.webp"))
        if let tempURL = writeTempFile(data: data, ext: "webp") {
            pb.setString(tempURL.absoluteString, forType: .fileURL)
        }
    }

    /// Fallback: copy NSImage directly (auto-negotiates pasteboard type)
    static func copyNSImage(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    /// Remove stale moji_* temp files (call on app launch)
    static func cleanupTempFiles() {
        let tmpDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tmpDir, includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix("moji_") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func writeTempFile(data: Data, ext: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("moji_\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
