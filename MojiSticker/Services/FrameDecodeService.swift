import Foundation
import ImageIO

actor FrameDecodeService {
    static let shared = FrameDecodeService()

    typealias FrameArray = [(image: CGImage, duration: TimeInterval)]

    private let cache = NSCache<NSURL, FrameCacheEntry>()
    private var activeTasks = 0
    private let maxConcurrency = 3
    private var slotWaiters: [(id: UUID, continuation: CheckedContinuation<Void, Never>)] = []

    init() {
        cache.countLimit = 30
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    /// Get frames for an animated image, using cache and concurrency control.
    /// Caller's task cancellation is respected — decode runs in calling context.
    nonisolated func frames(for url: URL, data: Data) async -> FrameArray? {
        // Check cache (requires actor hop)
        if let cached = await cachedFrames(for: url) {
            return cached
        }

        // Acquire concurrency slot (blocks if at limit, cancellable)
        let acquired = await acquireSlot()
        guard acquired else { return nil }

        // Decode in calling task's context (cancellation propagates)
        guard !Task.isCancelled else {
            await releaseSlot()
            return nil
        }

        let result = ImageProcessor.extractFrames(from: data)

        // Release slot and cache result
        await releaseSlot()

        guard !Task.isCancelled else { return nil }

        if let result {
            await storeInCache(result, for: url)
        }
        return result
    }

    /// Check if frames are already cached.
    func cachedFrames(for url: URL) -> FrameArray? {
        cache.object(forKey: url as NSURL)?.frames
    }

    // MARK: - Concurrency Control

    /// Acquire a decode slot. Returns false if cancelled while waiting.
    private func acquireSlot() async -> Bool {
        if activeTasks < maxConcurrency {
            activeTasks += 1
            return true
        }

        let waiterId = UUID()
        let acquired: Bool = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                slotWaiters.append((id: waiterId, continuation: continuation))
            }
            return true
        } onCancel: {
            Task { await self.cancelWaiter(id: waiterId) }
        }

        if acquired {
            activeTasks += 1
        }
        return acquired
    }

    /// Remove a cancelled waiter from the queue.
    private func cancelWaiter(id: UUID) {
        if let index = slotWaiters.firstIndex(where: { $0.id == id }) {
            let removed = slotWaiters.remove(at: index)
            removed.continuation.resume()
        }
    }

    private func releaseSlot() {
        activeTasks -= 1
        // Resume next waiter, skipping any that were already cancelled
        while !slotWaiters.isEmpty {
            let next = slotWaiters.removeFirst()
            next.continuation.resume()
            return
        }
    }

    private func storeInCache(_ frames: FrameArray, for url: URL) {
        let cost = Self.estimateCost(frames)
        let entry = FrameCacheEntry(frames: frames)
        cache.setObject(entry, forKey: url as NSURL, cost: cost)
    }

    private static func estimateCost(_ frames: FrameArray) -> Int {
        guard let first = frames.first else { return 0 }
        return first.image.width * first.image.height * 4 * frames.count
    }
}

// MARK: - Cache Entry Wrapper

private final class FrameCacheEntry: NSObject {
    let frames: [(image: CGImage, duration: TimeInterval)]

    init(frames: [(image: CGImage, duration: TimeInterval)]) {
        self.frames = frames
    }
}
