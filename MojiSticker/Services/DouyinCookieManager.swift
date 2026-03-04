import Foundation

struct DouyinCookieManager {
    private static var storageDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".moji")
    }

    private static var storageURL: URL {
        let dir = storageDir
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return dir.appendingPathComponent("douyin_cookies.json")
    }

    private static func ensureDirPermissions() {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: storageDir.path
        )
    }

    static func save(_ cookies: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(cookies) else { return false }
        do {
            try data.write(to: storageURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: storageURL.path
            )
            ensureDirPermissions()
            // Best-effort: exclude from backup
            var url = storageURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
            return true
        } catch {
            return false
        }
    }

    static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: storageURL),
              let cookies = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return cookies
    }

    static func clear() -> Bool {
        do {
            try FileManager.default.removeItem(at: storageURL)
            return true
        } catch {
            return false
        }
    }

    static func validate(_ cookies: [String: String]) -> (Bool, String) {
        guard let ttwid = cookies["ttwid"], !ttwid.isEmpty else {
            return (false, "缺少必需的 ttwid")
        }
        return (true, "")
    }
}

extension DouyinCookieManager {
    /// Migrate cookies from the legacy Python format (~/.moji/douyin_cookies.json)
    /// Legacy format wraps cookies in {"data": "<base64>"}, new format is plain JSON.
    static func migrateFromLegacy() -> Bool {
        guard let data = try? Data(contentsOf: storageURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encoded = json["data"] as? String,
              let decoded = Data(base64Encoded: encoded),
              let cookies = try? JSONDecoder().decode([String: String].self, from: decoded)
        else { return false }
        return save(cookies)
    }
}
