import Foundation

actor DouyinAPI {
    enum APIError: Error, LocalizedError {
        case cookieExpired
        case rateLimited
        case parameterError
        case networkError(Error)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .cookieExpired: return "Cookie 已过期，请重新设置"
            case .rateLimited: return "请求过于频繁，请稍后再试"
            case .parameterError: return "参数错误"
            case .networkError(let error): return "网络错误: \(error.localizedDescription)"
            case .invalidResponse: return "服务器响应异常"
            }
        }
    }

    private let baseURL = "https://www.douyin.com/aweme/v1/web/im/resource/emoticon/search"
    private let session: URLSession

    private let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://www.douyin.com/",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "sec-ch-ua": "\"Not_A Brand\";v=\"8\", \"Chromium\";v=\"120\"",
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": "\"macOS\"",
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-origin",
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    func search(
        keyword: String,
        cursor: String = "0",
        cookies: [String: String]
    ) async throws -> (urls: [URL], nextCursor: String, hasMore: Bool) {
        let request = try buildRequest(keyword: keyword, cursor: cursor, cookies: cookies)
        var lastError: Error = APIError.networkError(URLError(.unknown))

        for attempt in 0..<3 {
            do {
                let result = try await executeRequest(request, attempt: attempt)
                return result
            } catch let error as APIError where shouldRetryRateLimit(error) {
                try await Task.sleep(for: .seconds(3 * (attempt + 1)))
                continue
            } catch let error as APIError {
                throw error
            } catch {
                lastError = error
                try await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))
            }
        }
        throw APIError.networkError(lastError)
    }

    // MARK: - Private

    private func executeRequest(
        _ request: URLRequest,
        attempt: Int
    ) async throws -> (urls: [URL], nextCursor: String, hasMore: Bool) {
        let (data, httpResponse) = try await session.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            try mapHTTPStatus(http.statusCode)
        }

        let response: DouyinResponse
        do {
            response = try JSONDecoder().decode(DouyinResponse.self, from: data)
        } catch {
            // Non-JSON response (HTML blocked page) means cookie is missing/invalid
            if data.first == UInt8(ascii: "<") {
                throw APIError.cookieExpired
            }
            throw APIError.invalidResponse
        }

        switch response.statusCode {
        case 0: break
        case 2: throw APIError.cookieExpired
        case 5: throw APIError.parameterError
        case 8: throw APIError.rateLimited
        default: throw APIError.invalidResponse
        }

        let stickers = response.emoticonData?.stickerList ?? []
        let urls: [URL] = stickers.compactMap { sticker in
            let urlString = sticker.origin?.urlList.first ?? sticker.thumbnail?.urlList.first
            return urlString.flatMap { URL(string: $0) }
        }
        return (
            urls: urls,
            nextCursor: response.emoticonData?.nextCursor ?? "0",
            hasMore: response.emoticonData?.hasMore ?? false
        )
    }

    private func shouldRetryRateLimit(_ error: APIError) -> Bool {
        if case .rateLimited = error { return true }
        return false
    }

    private func mapHTTPStatus(_ statusCode: Int) throws {
        switch statusCode {
        case 200: return
        case 401, 403: throw APIError.cookieExpired
        case 429: throw APIError.rateLimited
        default: throw APIError.invalidResponse
        }
    }

    private func buildRequest(
        keyword: String,
        cursor: String,
        cookies: [String: String]
    ) throws -> URLRequest {
        let params: [String: String] = [
            "device_platform": "webapp",
            "aid": "1128",
            "channel": "pc_web",
            "keyword": keyword,
            "cursor": cursor,
            "count": "20",
            "pc_client_type": "1",
            "version_code": "170400",
            "version_name": "17.4.0",
            "cookie_enabled": "true",
            "screen_width": "1920",
            "screen_height": "1080",
            "browser_language": "zh-CN",
            "browser_platform": "MacIntel",
            "browser_name": "Chrome",
            "browser_version": "120.0.0.0",
            "browser_online": "true",
        ]

        var components = URLComponents(string: baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let cookieString = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        return request
    }
}
