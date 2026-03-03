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
        Task {
            let data: Data?
            if let existing = sticker.imageData {
                data = existing
            } else {
                data = await ImageCacheService.shared.data(for: sticker.url)
            }
            guard let data else { return }
            performCopy(data: data, index: index)
        }
    }

    // MARK: - Private

    private func performCopy(data: Data, index: Int) {
        let animType = ImageProcessor.detectAnimation(data)
        switch animType {
        case .gif:
            ClipboardService.copyAnimatedGIF(data: data)
        case .webp:
            ClipboardService.copyAnimatedWebP(data: data)
        case .none:
            if let image = NSImage(data: data) {
                ClipboardService.copyStatic(image: image)
            }
        }
        showCopyFeedback(for: index)
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
