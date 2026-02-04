//
//  FloatingPetWindow.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

import SwiftUI
import AppKit

final class FloatingPetWindowController: NSWindowController {
    @MainActor let stateModel = PetStateModel()
    private let controllerRef = ControllerRef<FloatingPetWindowController>()
    private var panel: ChatPanelWindowController?

    init() {
        let size: CGFloat = 240

        // 先创建 view（此时不需要 self）
        let rootView = PetRootView(controllerRef: controllerRef, stateModel: stateModel, size: size)
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let w = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: size, height: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.ignoresMouseEvents = false
        w.contentView = hosting

        super.init(window: w)

        controllerRef.value = self

        w.center()
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func currentApiKey() -> String? { KeychainStore.load() }

    func syncPanelPosition() {
        guard let win = window else { return }
        panel?.reposition(anchorRect: win.frame)
    }

    func showPanelNearPet() {
        guard let win = window else { return }
        let frame = win.frame

        if panel == nil {
            panel = ChatPanelWindowController(
                anchorRect: frame,
                apiKeyProvider: { [weak self] in self?.currentApiKey() },
                stateModel: stateModel
            )
        }

        panel?.show()
        syncPanelPosition() // 可选：保证首次显示就贴着机器人
    }
}

struct PetRootView: View {
    @ObservedObject var controllerRef: ControllerRef<FloatingPetWindowController>
    @ObservedObject var stateModel: PetStateModel
    let size: CGFloat

    @State private var isDragging = false

    var body: some View {
        ZStack {
            PNGSequencePlayerView(folderName: stateModel.state.assetFolder, size: size, loopSeconds: 5.0)
               }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onTapGesture {
            controllerRef.value?.showPanelNearPet()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    stateModel.state = .dragging
                }
                guard let win = controllerRef.value?.window else { return }
                let newOrigin = NSPoint(
                    x: win.frame.origin.x + value.translation.width,
                    y: win.frame.origin.y - value.translation.height
                )
                win.setFrameOrigin(newOrigin)
                controllerRef.value?.syncPanelPosition()
                
            }
            .onEnded { _ in
                isDragging = false
                stateModel.state = .idle
            }
    }
}
