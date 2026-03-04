import Foundation
import SwiftUI

@MainActor
@Observable
class SearchState {
    var keyword = ""
    var stickers: [StickerItem] = []
    var isLoading = false
    var hasMore = true
    var errorMessage: String?
    var copyFeedbackIndex: Int?

    private var cursor = "0"
    private var currentTask: Task<Void, Never>?
    private var copyRequestId = 0
    private let api = DouyinAPI()

    func search(_ keyword: String) {
        currentTask?.cancel()
        self.keyword = keyword
        self.stickers = []
        self.cursor = "0"
        self.hasMore = true
        self.errorMessage = nil

        currentTask = Task { await doSearch() }
    }

    func loadMore() {
        guard !isLoading, hasMore else { return }
        currentTask = Task { await doSearch() }
    }

    func copySticker(at index: Int) {
        guard index < stickers.count else { return }
        let sticker = stickers[index]
        copyRequestId += 1
        let requestId = copyRequestId
        showCopyFeedback(for: index)

        Task {
            let data: Data?
            if let existing = sticker.imageData {
                data = existing
            } else {
                data = await ImageCacheService.shared.data(for: sticker.url)
            }
            guard let data else { return }
            await performCopy(data: data, requestId: requestId)
        }
    }

    // MARK: - Private

    private func performCopy(data: Data, requestId: Int) async {
        let animType = ImageProcessor.detectAnimation(data)

        enum CopyPayload {
            case png(Data)
            case gif(Data)
            case webp(Data)
            case nsImage(NSImage)
        }

        let payload: CopyPayload? = await Task.detached {
            switch animType {
            case .gif:
                switch ImageProcessor.resizeAnimatedImage(data: data) {
                case .gif(let d): return .gif(d)
                case .png(let d): return .png(d)
                case nil: return .gif(data)
                }
            case .webp:
                switch ImageProcessor.resizeAnimatedImage(data: data) {
                case .gif(let d): return .gif(d)
                case .png(let d): return .png(d)
                case nil: return .webp(data) // keep original WebP type
                }
            case .none:
                if let d = ImageProcessor.resizeStaticImage(data: data) {
                    return .png(d)
                }
                // Fallback: use NSImage for universal pasteboard support
                if let img = NSImage(data: data) {
                    return .nsImage(img)
                }
                return nil
            }
        }.value

        guard copyRequestId == requestId, let payload else { return }

        switch payload {
        case .gif(let d):
            ClipboardService.copyAnimatedGIF(data: d)
        case .webp(let d):
            ClipboardService.copyAnimatedWebP(data: d)
        case .png(let d):
            ClipboardService.copyStatic(pngData: d)
        case .nsImage(let img):
            ClipboardService.copyNSImage(img)
        }
    }

    private func showCopyFeedback(for index: Int) {
        copyFeedbackIndex = index
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            if copyFeedbackIndex == index {
                copyFeedbackIndex = nil
            }
        }
    }

    private func doSearch() async {
        guard !keyword.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let cookies = DouyinCookieManager.load()
        do {
            let result = try await api.search(
                keyword: keyword,
                cursor: cursor,
                cookies: cookies
            )
            guard !Task.isCancelled else { return }

            let newItems = result.urls.map { StickerItem(url: $0) }
            stickers.append(contentsOf: newItems)
            cursor = result.nextCursor
            hasMore = result.hasMore
        } catch let error as DouyinAPI.APIError {
            guard !Task.isCancelled else { return }
            errorMessage = error.errorDescription
        } catch {
            if !Task.isCancelled {
                errorMessage = "网络错误"
            }
        }
    }
}
