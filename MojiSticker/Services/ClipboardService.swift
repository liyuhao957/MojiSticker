import AppKit

struct ClipboardService {
    static func copyStatic(image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
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
