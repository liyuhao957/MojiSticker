import SwiftUI

struct SearchWindow: View {
    @State private var searchState = SearchState()
    @State private var searchText = ""
    @State private var showSettings = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if showSettings {
                CookieSettingsPanel(isExpanded: $showSettings)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            errorBanner
            StickerGridView(state: searchState)
        }
        .frame(width: 380, height: 520)
        .overlay(alignment: .bottom) {
            if searchState.showCopyToast {
                CopyToast()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: searchState.showCopyToast)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { isSearchFocused = true }
        .onKeyPress(.escape) {
            if showSettings {
                withAnimation(.easeInOut(duration: 0.2)) { showSettings = false }
                return .handled
            }
            NSApp.keyWindow?.close()
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .mojiIPCSearch)) { note in
            if let keyword = note.object as? String {
                searchText = keyword
                performSearch()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("搜索表情包...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)
                .onSubmit { performSearch() }
                .padding(.leading, 16)
                .padding(.vertical, 12)

            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(showSettings ? .primary : .secondary)
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
