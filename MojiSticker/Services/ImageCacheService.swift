import Foundation
import AppKit
import CryptoKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSURL, NSData>()
    private let cacheDir: URL

    init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".moji/cache")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.cacheDir = base
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func data(for url: URL) -> Data? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached as Data
        }
        let filePath = diskPath(for: url)
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        memoryCache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    func store(_ data: Data, for url: URL) {
        memoryCache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        let filePath = diskPath(for: url)
        try? data.write(to: filePath)
    }

    /// Schedule disk cache cleanup on a background queue after delay.
    func scheduleDiskCleanup() {
        let dir = cacheDir
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            Self.cleanDiskCache(dir: dir, maxBytes: 200 * 1024 * 1024, targetBytes: 150 * 1024 * 1024)
        }
    }

    private func diskPath(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent(hash)
    }

    // MARK: - Disk Cleanup

    private static func cleanDiskCache(dir: URL, maxBytes: Int, targetBytes: Int) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        var files: [(url: URL, date: Date, size: Int)] = []
        var totalSize = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { continue }
            files.append((fileURL, date, size))
            totalSize += size
        }

        guard totalSize > maxBytes else { return }

        // Sort oldest first
        files.sort { $0.date < $1.date }

        for file in files {
            guard totalSize > targetBytes else { break }
            do {
                try fm.removeItem(at: file.url)
                totalSize -= file.size
            } catch {
                // Skip files that can't be deleted
            }
        }
    }
}
