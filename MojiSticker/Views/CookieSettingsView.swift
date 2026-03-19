import SwiftUI

struct CookieSettingsPanel: View {
    @Binding var isExpanded: Bool
    @State private var cookieText = ""
    @State private var parsedCookies: [String: String] = [:]
    @State private var statusMessage = ""
    @State private var hasTtwid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            editorField
            statusRow
            buttonRow
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear(perform: loadExistingCookies)
    }

    // MARK: - Sections

    private var headerRow: some View {
        Text("可直接粘贴抖音 Cookie 字符串，或浏览器 Copy as cURL 的完整内容")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var editorField: some View {
        TextEditor(text: $cookieText)
            .font(.system(.caption, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(height: 80)
            .onChange(of: cookieText) { _, newValue in
                parseCookieString(newValue)
            }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            if !cookieText.isEmpty {
                Text("\(parsedCookies.count) 个字段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ttwid")
                    .font(.caption.bold())
                    .foregroundStyle(hasTtwid ? .green : .red)
                + Text(hasTtwid ? " ✓" : " ✗")
                    .font(.caption)
                    .foregroundStyle(hasTtwid ? .green : .red)
            }
            Spacer()
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var buttonRow: some View {
        HStack {
            Button("粘贴") { pasteFromClipboard() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button("清除") { clearCookies() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("退出 App") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            Spacer()
            Button("取消") { collapse() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("保存") { saveCookies() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(parsedCookies.isEmpty)
        }
    }

    // MARK: - Logic

    private func parseCookieString(_ raw: String) {
        let result = CookieInputParser.parse(raw)
        guard !result.cookieString.isEmpty else {
            parsedCookies = [:]
            hasTtwid = false
            statusMessage = ""
            return
        }

        let normalized = result.cookieString
        if normalized != raw.trimmingCharacters(in: .whitespacesAndNewlines) {
            cookieText = normalized
        }

        parsedCookies = result.cookies
        hasTtwid = result.cookies["ttwid"] != nil
        statusMessage = switch result.source {
        case .rawCookie: ""
        case .curlCookieArgument: "已从 cURL 提取 Cookie"
        case .cookieHeader: "已识别 Cookie 头"
        }
    }

    private func loadExistingCookies() {
        let cookies = DouyinCookieManager.load()
        guard !cookies.isEmpty else { return }
        cookieText = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        parseCookieString(cookieText)
    }

    private func saveCookies() {
        guard !parsedCookies.isEmpty else { return }
        let (valid, message) = DouyinCookieManager.validate(parsedCookies)
        if !valid {
            statusMessage = message
            return
        }
        if DouyinCookieManager.save(parsedCookies) {
            collapse()
        } else {
            statusMessage = "保存失败"
        }
    }

    private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            statusMessage = "剪贴板里没有可用文本"
            return
        }
        cookieText = text
        parseCookieString(text)
    }

    private func clearCookies() {
        _ = DouyinCookieManager.clear()
        cookieText = ""
        parsedCookies = [:]
        hasTtwid = false
        statusMessage = ""
    }

    private func collapse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
    }
}
