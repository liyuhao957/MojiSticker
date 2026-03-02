import Foundation
import Security

struct DouyinCookieManager {
    private static let service = "com.moji.MojiSticker.douyin"
    private static let account = "cookies"

    static func save(_ cookies: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(cookies) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let cookies = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return cookies
    }

    static func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
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
    static func migrateFromLegacy() -> Bool {
        let legacyPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".moji/douyin_cookies.json")
        guard let data = try? Data(contentsOf: legacyPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encoded = json["data"] as? String,
              let decoded = Data(base64Encoded: encoded),
              let cookies = try? JSONDecoder().decode([String: String].self, from: decoded)
        else { return false }
        return save(cookies)
    }
}
