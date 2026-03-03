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

    private func diskPath(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent(hash)
    }
}
