import SwiftUI
import AppKit

// MARK: - PreviewPanelController

class PreviewPanelController {
    static let shared = PreviewPanelController()

    private var panel: NSPanel?
    private var currentURL: URL?
    private var hideGeneration = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    func show(data: Data, url: URL, at screenPoint: NSPoint) {
        // Always cancel pending hide and bump generation first
        hideGeneration += 1

        // Idempotent: same URL with panel already visible → update position only
        if url == currentURL, let panel {
            let pos = adjustPosition(
                origin: screenPoint,
                size: panel.frame.size,
                offset: NSPoint(x: 12, y: -12)
            )
            panel.setFrameOrigin(pos)
            return
        }

        // Different URL or no panel → close old and build new
        closePanel()
        currentURL = url

        let built = buildPanel(data: data, url: url)
        let hostingView = NSHostingView(rootView: built.contentView)
        built.panel.contentView = hostingView
        built.panel.setContentSize(hostingView.fittingSize)

        let pos = adjustPosition(
            origin: screenPoint,
            size: hostingView.fittingSize,
            offset: NSPoint(x: 12, y: -12)
        )
        built.panel.setFrameOrigin(pos)
        built.panel.orderFront(nil)
        self.panel = built.panel
    }

    func scheduleHide() {
        let generation = hideGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.hideGeneration == generation else { return }
            self.hide()
        }
    }

    func hide() {
        hideGeneration += 1
        closePanel()
        currentURL = nil
    }

    func hideIfShowing(url: URL) {
        if currentURL == url {
            hide()
        }
    }

    // MARK: - Private

    private func closePanel() {
        panel?.close()
        panel = nil
    }

    private func buildPanel(
        data: Data, url: URL
    ) -> (panel: NSPanel, contentView: PreviewContentView) {
        let maxSide: CGFloat = 320
        let animType = ImageProcessor.detectAnimation(data)

        let previewView = PreviewContentView(
            data: data,
            url: url,
            animationType: animType,
            maxSide: maxSide
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: maxSide + 20, height: maxSide + 20),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.ignoresMouseEvents = true

        return (panel, previewView)
    }

    private func adjustPosition(
        origin: NSPoint,
        size: NSSize,
        offset: NSPoint
    ) -> NSPoint {
        var pos = NSPoint(
            x: origin.x + offset.x,
            y: origin.y + offset.y - size.height
        )
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(origin)
        }) ?? NSScreen.main else {
            return pos
        }
        let screenFrame = screen.visibleFrame
        if pos.x + size.width > screenFrame.maxX - 8 {
            pos.x = max(screenFrame.minX + 8, screenFrame.maxX - size.width - 8)
        }
        if pos.y < screenFrame.minY + 8 {
            pos.y = max(screenFrame.minY + 8, origin.y + 12)
        }
        return pos
    }
}

// MARK: - PreviewContentView

struct PreviewContentView: View {
    let data: Data
    let url: URL
    let animationType: ImageProcessor.AnimationType
    let maxSide: CGFloat

    @State private var frames: [(image: CGImage, duration: TimeInterval)]?
    @State private var currentFrame = 0
    @State private var animationTimer: Timer?

    var body: some View {
        Group {
            if let frames, !frames.isEmpty, currentFrame < frames.count {
                Image(frames[currentFrame].image, scale: 2.0, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: maxSide, maxHeight: maxSide)
        .padding(10)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 4)
        .task { await startAnimationIfNeeded() }
        .onDisappear { stopAnimation() }
    }

    private func startAnimationIfNeeded() async {
        guard animationType != .none else { return }

        // Use FrameDecodeService for cached + deduplicated frame extraction
        guard let extractedFrames = await FrameDecodeService.shared.frames(
            for: url, data: data
        ), !extractedFrames.isEmpty else { return }

        guard !Task.isCancelled else { return }
        self.frames = extractedFrames
        let avgDuration = extractedFrames.map(\.duration).reduce(0, +)
            / Double(extractedFrames.count)
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: max(avgDuration, 0.04),
            repeats: true
        ) { _ in
            currentFrame = (currentFrame + 1) % (frames?.count ?? 1)
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
