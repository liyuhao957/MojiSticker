import Foundation

struct StickerItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var imageData: Data?
    var isAnimated: Bool = false
    var animationType: AnimationType = .none

    enum AnimationType {
        case none, gif, webp
    }
}
