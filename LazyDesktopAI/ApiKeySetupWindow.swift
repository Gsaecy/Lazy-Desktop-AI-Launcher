//
//  ApiKeySetupWindow.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//
import SwiftUI
import AppKit
import Combine
final class ApiKeySetupWindowController: NSWindowController {
    init(onSaved: @escaping () -> Void) {
        let vm = ApiKeySetupViewModel(onSaved: onSaved)
        let hosting = NSHostingView(rootView: ApiKeySetupView(viewModel: vm))
        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        w.title = "配置 DeepSeek API Key"
        w.center()
        w.isReleasedWhenClosed = false
        w.contentView = hosting
        super.init(window: w)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
@MainActor
final class ApiKeySetupViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var errorText: String? = nil
    private let onSaved: () -> Void
    init(onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
    }
    func save() {
        let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else {
            errorText = "请输入 API Key"
            return
        }
        do {
            try KeychainStore.save(k)
            let loaded = KeychainStore.load() ?? ""
            print("[KEYCHAIN] saved ok, len=\(k.count), reload_len=\(loaded.count)")
            errorText = nil
            onSaved()
        } catch {
            print("[KEYCHAIN] save failed:", error)
            errorText = "保存失败：\(error.localizedDescription)"
        }
    }
}
struct ApiKeySetupView: View {
    @ObservedObject var viewModel: ApiKeySetupViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("请输入你的 DeepSeek API Key（仅保存到本机 Keychain，不会上传）")
                .font(.headline)
            SecureField("sk-...（粘贴到这里）", text: $viewModel.apiKey)
                .textFieldStyle(.roundedBorder)
            if let e = viewModel.errorText {
                Text(e).foregroundColor(.red).font(.caption)
            }
            HStack {
                Button("保存") { viewModel.save() }
                    .keyboardShortcut(.defaultAction)
                Button("清除已保存的 Key") {
                    KeychainStore.clear()
                    viewModel.apiKey = ""
                }
                Spacer()
                Text("获取 Key：DeepSeek 控制台 → API Keys")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
}
