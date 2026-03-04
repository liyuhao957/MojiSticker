import Foundation
import ImageIO
import AppKit
import UniformTypeIdentifiers

struct ImageProcessor {
    static let stickerMaxSide: CGFloat = 160
    enum AnimationType {
        case none, gif, webp
    }

    enum ResizedResult {
        case gif(Data)
        case png(Data)
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

    // MARK: - Resize for Clipboard

    /// Resize static image to max side, always output PNG data
    static func resizeStaticImage(data: Data, maxSide: CGFloat = stickerMaxSide) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, thumb, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    /// Resize animated GIF/WebP to max side, output GIF or fallback PNG
    static func resizeAnimatedImage(data: Data, maxSide: CGFloat = stickerMaxSide) -> ResizedResult? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        // Determine original size from first frame
        guard let firstImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let origW = firstImage.width
        let origH = firstImage.height
        if max(origW, origH) <= Int(maxSide) && count <= 200 && isGIF(data) {
            return .gif(data) // Already small GIF, no resize needed
        }

        let scale = min(maxSide / CGFloat(origW), maxSide / CGFloat(origH), 1.0)
        let newW = Int(CGFloat(origW) * scale)
        let newH = Int(CGFloat(origH) * scale)
        let frameLimit = min(count, 200)

        // Read container-level GIF properties (loop count)
        let sourceProps = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let gifContainerProps = sourceProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, UTType.gif.identifier as CFString, frameLimit, nil
        ) else { return nil }

        // Set container-level GIF properties (loop count)
        if let containerProps = gifContainerProps {
            let destProps: [CFString: Any] = [kCGImagePropertyGIFDictionary: containerProps]
            CGImageDestinationSetProperties(dest, destProps as CFDictionary)
        } else {
            // Default: loop forever
            let loopProps: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
            ]
            CGImageDestinationSetProperties(dest, loopProps as CFDictionary)
        }

        for i in 0..<frameLimit {
            autoreleasepool {
                guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { return }
                let frameProps = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
                let gifFrameProps = frameProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]

                if let resized = resizeFrame(frame, width: newW, height: newH) {
                    var destFrameProps: [CFString: Any] = [:]
                    if let gp = gifFrameProps {
                        destFrameProps[kCGImagePropertyGIFDictionary] = gp
                    } else {
                        destFrameProps[kCGImagePropertyGIFDictionary] = [
                            kCGImagePropertyGIFDelayTime: 0.05
                        ]
                    }
                    CGImageDestinationAddImage(dest, resized, destFrameProps as CFDictionary)
                }
            }
        }

        guard CGImageDestinationFinalize(dest) else { return nil }
        let result = mutableData as Data

        // Size check: if > 5MB, try reducing frames
        if result.count > 5_000_000 {
            return reduceFrameRate(source: source, origW: origW, origH: origH,
                                   newW: newW, newH: newH, frameLimit: frameLimit)
        }
        return .gif(result)
    }

    // MARK: - Resize Helpers

    private static func resizeFrame(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// Reduce frame rate by sampling every other frame, fallback to first frame PNG
    private static func reduceFrameRate(
        source: CGImageSource, origW: Int, origH: Int,
        newW: Int, newH: Int, frameLimit: Int
    ) -> ResizedResult? {
        let sampledCount = (frameLimit + 1) / 2
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, UTType.gif.identifier as CFString, sampledCount, nil
        ) else { return nil }

        let loopProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(dest, loopProps as CFDictionary)

        for i in stride(from: 0, to: frameLimit, by: 2) {
            autoreleasepool {
                guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { return }
                let frameProps = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
                let gifFrameProps = frameProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]

                if let resized = resizeFrame(frame, width: newW, height: newH) {
                    // Double the delay to compensate for dropped frames
                    var adjustedProps: [CFString: Any] = [:]
                    if let gp = gifFrameProps {
                        var mutableGP = gp
                        if let delay = gp[kCGImagePropertyGIFDelayTime] as? Double {
                            mutableGP[kCGImagePropertyGIFDelayTime] = delay * 2
                        }
                        if let delay = gp[kCGImagePropertyGIFUnclampedDelayTime] as? Double {
                            mutableGP[kCGImagePropertyGIFUnclampedDelayTime] = delay * 2
                        }
                        adjustedProps[kCGImagePropertyGIFDictionary] = mutableGP
                    } else {
                        adjustedProps[kCGImagePropertyGIFDictionary] = [
                            kCGImagePropertyGIFDelayTime: 0.1
                        ]
                    }
                    CGImageDestinationAddImage(dest, resized, adjustedProps as CFDictionary)
                }
            }
        }

        guard CGImageDestinationFinalize(dest) else { return nil }
        let result = mutableData as Data
        // Still too big? Fallback to first frame as static PNG
        if result.count > 5_000_000 {
            if let pngData = firstFramePNG(source: source, width: newW, height: newH) {
                return .png(pngData)
            }
            return nil
        }
        return .gif(result)
    }

    /// Fallback: extract and resize first frame as static PNG
    private static func firstFramePNG(source: CGImageSource, width: Int, height: Int) -> Data? {
        guard let frame = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let resized = resizeFrame(frame, width: width, height: height) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, resized, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
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
