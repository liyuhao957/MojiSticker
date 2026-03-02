import SwiftUI

struct SearchWindow: View {
    @State private var searchState = SearchState()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            errorBanner
            StickerGridView(state: searchState)
        }
        .frame(width: 380, height: 520)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { isSearchFocused = true }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("搜索表情包...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)
                .onSubmit { performSearch() }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Button(action: performSearch) {
                Text("\u{1F50D}")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = searchState.errorMessage {
            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.67, green: 0.2, blue: 0.2))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)
        }
    }

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searchState.search(trimmed)
    }
}

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
