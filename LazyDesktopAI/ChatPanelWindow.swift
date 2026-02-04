//  ChatPanelWindow.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//
import SwiftUI
import AppKit
import Combine
final class ChatPanelWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: ChatViewModel

    init(anchorRect: CGRect, apiKeyProvider: @escaping () -> String?, stateModel: PetStateModel) {
        self.viewModel = ChatViewModel(apiKeyProvider: apiKeyProvider, stateModel: stateModel)

        let hosting = NSHostingView(rootView: ChatPanelView(viewModel: viewModel))

        let w = NSPanel(
            contentRect: NSRect(x: anchorRect.maxX + 8, y: anchorRect.midY - 180, width: 360, height: 280),
            // 保持红绿灯默认行为（最小化/缩放/排列），不要劫持成业务按钮
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        w.isReleasedWhenClosed = false
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .windowBackgroundColor.withAlphaComponent(0.95)
        w.title = "Ask AI"
        w.contentView = hosting

        super.init(window: w)
        w.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reposition(anchorRect: CGRect) {
        guard let w = window else { return }
        let newFrame = NSRect(
            x: anchorRect.maxX + 8,
            y: anchorRect.midY - w.frame.height / 2,
            width: w.frame.width,
            height: w.frame.height
        )
        w.setFrame(newFrame, display: true)
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var answer: String = ""
    @Published var isLoading: Bool = false
    @Published var errorText: String? = nil

    private let apiKeyProvider: () -> String?
    private let stateModel: PetStateModel

    init(apiKeyProvider: @escaping () -> String?, stateModel: PetStateModel) {
        self.apiKeyProvider = apiKeyProvider
        self.stateModel = stateModel
    }

    func send() {
        let q = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        errorText = nil
        answer = ""
        isLoading = true
        stateModel.state = .thinking

        Task {
            defer {
                Task { @MainActor in
                    self.isLoading = false
                    self.stateModel.state = .idle
                }
            }

            guard let key = apiKeyProvider(), !key.isEmpty else {
                await MainActor.run { self.errorText = "请先设置 DeepSeek API Key（下一步我给你接 Keychain 设置页）" }
                return
            }

            do {
                let client = DeepSeekClient(apiKey: key)
                let res = try await client.ask(q)
                await MainActor.run { self.answer = res }
            } catch {
                await MainActor.run { self.errorText = String(describing: error) }
            }
        }
    }

    func clearAll() {
        prompt = ""
        answer = ""
        errorText = nil
    }

    func copyAllToPasteboard() {
        let q = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !q.isEmpty { parts.append("Q: \(q)") }
        if !a.isEmpty { parts.append("A: \(a)") }
        if parts.isEmpty { return }

        let text = parts.joined(separator: "\n\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

struct ChatPanelView: View {
       
    @ObservedObject var viewModel: ChatViewModel
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("输入问题，回车发送", text: $viewModel.prompt)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.send() }

                Button("发送") { viewModel.send() }
                    .disabled(viewModel.isLoading)

                Button {
                    viewModel.copyAllToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("复制全部")
                .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Image(systemName: "trash")
                }
                .help("清空")
                .disabled(viewModel.prompt.isEmpty && viewModel.answer.isEmpty && viewModel.errorText == nil)
            }
            
            .font(.caption)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let e = viewModel.errorText {
                Text(e).foregroundColor(.red).font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView {
                Text(viewModel.answer.isEmpty ? "回答会显示在这里…" : viewModel.answer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(Color.black.opacity(0.04))
            .cornerRadius(10)
        }
        .padding(12)
       }
   }
