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
        Text("从浏览器复制抖音 Cookie 字符串粘贴到下方")
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
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedCookies = [:]
            hasTtwid = false
            return
        }
        var result: [String: String] = [:]
        for pair in trimmed.components(separatedBy: "; ") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { result[key] = value }
        }
        parsedCookies = result
        hasTtwid = result["ttwid"] != nil
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
