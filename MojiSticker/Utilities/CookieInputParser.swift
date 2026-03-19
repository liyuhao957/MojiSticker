import Foundation

enum CookieInputParser {
    struct Result {
        enum Source {
            case rawCookie
            case curlCookieArgument
            case cookieHeader
        }

        let cookieString: String
        let cookies: [String: String]
        let source: Source
    }

    static func parse(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(cookieString: "", cookies: [:], source: .rawCookie)
        }

        let extracted = extractCookieString(from: trimmed)
        let cookies = parseCookiePairs(extracted.cookieString)
        return Result(
            cookieString: extracted.cookieString,
            cookies: cookies,
            source: extracted.source
        )
    }

    private static func extractCookieString(from raw: String) -> Result {
        if let cookie = firstMatch(
            in: raw,
            patterns: [
                #"(?:^|\s)(?:-b|--cookie)\s+'([^']+)'"#,
                #"(?:^|\s)(?:-b|--cookie)\s+"([^"]+)""#
            ]
        ) {
            return Result(
                cookieString: cookie.trimmingCharacters(in: .whitespacesAndNewlines),
                cookies: [:],
                source: .curlCookieArgument
            )
        }

        if let cookie = firstMatch(
            in: raw,
            patterns: [
                #"(?:^|\s)(?:-H|--header)\s+'cookie:\s*([^']+)'"#,
                #"(?:^|\s)(?:-H|--header)\s+"cookie:\s*([^"]+)""#
            ]
        ) {
            return Result(
                cookieString: cookie.trimmingCharacters(in: .whitespacesAndNewlines),
                cookies: [:],
                source: .cookieHeader
            )
        }

        let lowercased = raw.lowercased()
        if lowercased.hasPrefix("cookie:") {
            let cookie = raw.dropFirst("cookie:".count)
            return Result(
                cookieString: String(cookie).trimmingCharacters(in: .whitespacesAndNewlines),
                cookies: [:],
                source: .cookieHeader
            )
        }

        return Result(cookieString: raw, cookies: [:], source: .rawCookie)
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let captureRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            return String(text[captureRange])
        }
        return nil
    }

    private static func parseCookiePairs(_ cookieString: String) -> [String: String] {
        var result: [String: String] = [:]

        for pair in cookieString.split(separator: ";", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            result[key] = value
        }

        return result
    }
}
