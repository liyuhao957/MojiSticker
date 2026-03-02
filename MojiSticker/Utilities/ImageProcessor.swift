import Foundation
import ImageIO
import AppKit

struct ImageProcessor {
    enum AnimationType {
        case none, gif, webp
    }

    static func isGIF(_ data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let header = data.prefix(6)
        return header.elementsEqual("GIF87a".utf8) || header.elementsEqual("GIF89a".utf8)
    }

    static func isAnimatedWebP(_ data: Data) -> Bool {
        guard data.count > 20,
              data.prefix(4).elementsEqual("RIFF".utf8),
              data[8..<12].elementsEqual("WEBP".utf8)
        else { return false }

        if data[12..<16].elementsEqual("VP8X".utf8) {
            return data[20] & 0x02 != 0
        }
        let searchRange = data.prefix(min(data.count, 500))
        return searchRange.range(of: "ANIM".data(using: .utf8)!) != nil
    }

    static func detectAnimation(_ data: Data) -> AnimationType {
        if isGIF(data) { return .gif }
        if isAnimatedWebP(data) { return .webp }
        return .none
    }

    /// Extract frames from animated image using ImageIO
    static func extractFrames(from data: Data) -> [(image: CGImage, duration: TimeInterval)]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        var frames: [(CGImage, TimeInterval)] = []
        for i in 0..<min(count, 200) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let duration = frameDuration(source: source, index: i)
            frames.append((cgImage, max(duration, 0.02)))
        }
        return frames.isEmpty ? nil : frames
    }

    /// Get first frame as NSImage, scaled to maxSide
    static func firstFrame(from data: Data, maxSide: CGFloat = 64) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: thumb, size: NSSize(width: thumb.width, height: thumb.height))
    }

    // MARK: - Private

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.05
        }
        // Try GIF properties
        if let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            return (gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gifProps[kCGImagePropertyGIFDelayTime] as? Double)
                ?? 0.05
        }
        // Try WebP properties
        if let webpProps = props[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
            if let delay = webpProps["UnclampedDelayTime" as CFString] as? Double {
                return delay
            }
            if let delay = webpProps["DelayTime" as CFString] as? Double {
                return delay
            }
        }
        return 0.05
    }
}
