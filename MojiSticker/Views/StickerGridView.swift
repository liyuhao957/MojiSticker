import SwiftUI

struct StickerGridView: View {
    @Bindable var state: SearchState

    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(state.stickers.enumerated()), id: \.element.id) { index, sticker in
                    StickerCell(
                        sticker: sticker,
                        index: index,
                        isCopyFeedback: state.copyFeedbackIndex == index,
                        onTap: { state.copySticker(at: index) },
                        onHover: { hovering, data in
                            if hovering, let data {
                                let mouseLocation = NSEvent.mouseLocation
                                PreviewPanelController.shared.show(data: data, at: mouseLocation)
                            } else {
                                PreviewPanelController.shared.hide()
                            }
                        }
                    )
                    .onAppear {
                        if index == state.stickers.count - 4 {
                            state.loadMore()
                        }
                    }
                }
            }
            .padding(4)

            if state.isLoading {
                ProgressView("加载中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}
