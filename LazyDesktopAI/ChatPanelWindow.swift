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

    // “默认窗口大小”= 用户在非全屏/非半屏时的正常大小
    private var defaultFrame: NSRect?
    private var exitFullScreenRestorePending = false

    private var observerTokens: [NSObjectProtocol] = []

    init(anchorRect: CGRect, apiKeyProvider: @escaping () -> String?, stateModel: PetStateModel) {
        self.viewModel = ChatViewModel(apiKeyProvider: apiKeyProvider, stateModel: stateModel)

        let hosting = NSHostingView(rootView: ChatPanelView(viewModel: viewModel))

        // 用 NSWindow（而不是 NSPanel）来获得更“系统原生”的绿灯/平铺/全屏行为。
        let w = NSWindow(
            contentRect: NSRect(x: anchorRect.maxX + 8, y: anchorRect.midY - 180, width: 360, height: 280),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        w.isReleasedWhenClosed = false
        // 关键：floating 窗口会导致全屏/平铺行为异常（你看到的“点绿灯没反应”）。
        // 为了让绿灯（全屏/半屏）按系统预期工作，这里用 normal level。
        w.level = .normal
        w.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
        w.isOpaque = false
        w.backgroundColor = .windowBackgroundColor.withAlphaComponent(0.95)
        w.title = "Ask AI"
        w.contentView = hosting

        // 允许系统的绿灯悬停菜单（半屏/全屏/排列），但我们会在 windowShouldZoom 里修复“半屏后无法恢复”的问题。

        super.init(window: w)
        w.delegate = self

        defaultFrame = w.frame
        startObservingWindowChanges(w)
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

    deinit {
        for t in observerTokens { NotificationCenter.default.removeObserver(t) }
        observerTokens.removeAll()
    }

    // MARK: - Green button logic

    // 用 delegate 截获“点击绿灯”的行为（比改 button target/action 更稳定）。
    // - 默认大小 → 进入全屏
    // - 非默认（含全屏/任意半屏/任意排列） → 恢复默认大小
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        if isAtDefaultSize(window) {
            defaultFrame = window.frame
            exitFullScreenRestorePending = false
            window.toggleFullScreen(nil)
        } else {
            restoreToDefault(window)
        }
        return false
    }

    private func restoreToDefault(_ w: NSWindow) {
        guard let df = defaultFrame else { return }

        if w.styleMask.contains(.fullScreen) {
            // 先退出全屏，等退出完成再 setFrame
            exitFullScreenRestorePending = true
            w.toggleFullScreen(nil)
            return
        }

        exitFullScreenRestorePending = false

        // 从“平铺(半屏/排列)”状态出来时，直接 setFrame 可能会被系统吞掉。
        // 这里做两次（当前 runloop + 轻微延迟）以提高成功率。
        w.setFrame(df, display: true, animate: true)
        DispatchQueue.main.async { [weak w] in
            guard let w else { return }
            w.setFrame(df, display: true, animate: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak w] in
            guard let w else { return }
            w.setFrame(df, display: true, animate: true)
        }
    }

    private func startObservingWindowChanges(_ w: NSWindow) {
        let nc = NotificationCenter.default

        // 退出全屏后恢复 default frame
        observerTokens.append(
            nc.addObserver(forName: NSWindow.didExitFullScreenNotification, object: w, queue: .main) { [weak self] _ in
                guard let self, let w = self.window, self.exitFullScreenRestorePending else { return }
                self.exitFullScreenRestorePending = false
                if let df = self.defaultFrame {
                    w.setFrame(df, display: true, animate: true)
                }
            }
        )

        // 用户在“正常状态”手动调整窗口大小时，把它当作新的默认大小
        observerTokens.append(
            nc.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: w, queue: .main) { [weak self] _ in
                guard let self, let w = self.window else { return }
                if !w.styleMask.contains(.fullScreen), !self.isTiledFrame(w.frame, in: w.screen) {
                    self.defaultFrame = w.frame
                }
            }
        )
    }

    private func isAtDefaultSize(_ w: NSWindow) -> Bool {
        guard let df = defaultFrame else { return true }
        if w.styleMask.contains(.fullScreen) { return false }
        if isTiledFrame(w.frame, in: w.screen) { return false }
        return approxEqualRect(w.frame, df, tol: 2)
    }

    private func isTiledFrame(_ frame: NSRect, in screen: NSScreen?) -> Bool {
        // 尽量宽松地识别“平铺/排列”状态：只要 frame 很像屏幕可用区域的某个常见分割，就认为是 tiled。
        guard let s = screen else { return false }
        let vf = s.visibleFrame

        func approx(_ a: CGFloat, _ b: CGFloat, tol: CGFloat = 6.0) -> Bool { abs(a - b) <= tol }

        // 常见宽度比例：1/2、1/3、2/3
        let w2 = vf.width / 2
        let w3 = vf.width / 3
        let w23 = vf.width * 2 / 3

        // 常见高度比例：1/2
        let h2 = vf.height / 2

        let fullH = approx(frame.height, vf.height)
        let halfH = approx(frame.height, h2)

        let halfW = approx(frame.width, w2)
        let oneThirdW = approx(frame.width, w3)
        let twoThirdW = approx(frame.width, w23)

        // 左右半屏/三分屏/二三分屏（满高）
        let verticalSlices = fullH && (halfW || oneThirdW || twoThirdW)
        // 四分屏（半高 + 半宽）
        let quarters = halfH && halfW

        return verticalSlices || quarters
    }

    private func approxEqualRect(_ a: NSRect, _ b: NSRect, tol: CGFloat) -> Bool {
        abs(a.origin.x - b.origin.x) <= tol &&
        abs(a.origin.y - b.origin.y) <= tol &&
        abs(a.size.width - b.size.width) <= tol &&
        abs(a.size.height - b.size.height) <= tol
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
