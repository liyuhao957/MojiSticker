import SwiftUI

struct StickerCell: View {
    let sticker: StickerItem
    let index: Int
    let isCopyFeedback: Bool
    let onTap: () -> Void
    let onHover: (Bool, Data?) -> Void

    @State private var imageData: Data?
    @State private var frames: [(image: CGImage, duration: TimeInterval)]?
    @State private var currentFrame = 0
    @State private var isHovering = false
    @State private var animationTimer: Timer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageContent
                .frame(width: 64, height: 64)

            animationBadge
        }
        .frame(width: 72, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCopyFeedback ? Color.orange.opacity(0.3) : .clear, lineWidth: 1)
        )
        .onTapGesture { onTap() }
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering, imageData)
            handleHoverAnimation(hovering)
        }
        .task { await loadImage() }
        .onDisappear { stopAnimation() }
    }

    // MARK: - View Components

    @ViewBuilder
    private var imageContent: some View {
        if let frames, !frames.isEmpty, currentFrame < frames.count {
            Image(frames[currentFrame].image, scale: 2.0, label: Text(""))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let imageData, let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
                .scaleEffect(0.5)
        }
    }

    @ViewBuilder
    private var animationBadge: some View {
        if let data = imageData {
            let animType = ImageProcessor.detectAnimation(data)
            if animType != .none {
                Text(animType == .gif ? "GIF" : "动图")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(2)
            }
        }
    }

    private var backgroundColor: Color {
        if isCopyFeedback { return Color.orange.opacity(0.08) }
        if isHovering { return Color.orange.opacity(0.1) }
        return Color.white.opacity(0.8)
    }

    // MARK: - Logic

    private func loadImage() async {
        if let cached = await ImageCacheService.shared.data(for: sticker.url) {
            self.imageData = cached
        } else {
            do {
                let (data, _) = try await URLSession.shared.data(from: sticker.url)
                await ImageCacheService.shared.store(data, for: sticker.url)
                self.imageData = data
            } catch {
                // Silently ignore cancelled/network errors
            }
        }
        // Extract frames if animated
        if let data = imageData, ImageProcessor.detectAnimation(data) != .none {
            self.frames = ImageProcessor.extractFrames(from: data)
        }
    }

    private func handleHoverAnimation(_ hovering: Bool) {
        if hovering, let frames, !frames.isEmpty {
            startAnimation(frames: frames)
        } else {
            stopAnimation()
        }
    }

    private func startAnimation(frames: [(image: CGImage, duration: TimeInterval)]) {
        stopAnimation()
        let avgDuration = frames.map(\.duration).reduce(0, +) / Double(frames.count)
        let interval = max(avgDuration, 0.04)
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            currentFrame = (currentFrame + 1) % frames.count
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentFrame = 0
    }
}
