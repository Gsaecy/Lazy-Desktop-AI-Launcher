//
//  PNGSequencePlayerView.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

import SwiftUI
import AppKit
import Combine

final class PNGSequencePlayer: ObservableObject {
    @Published var frames: [NSImage] = []
    
    func load(prefix: String) {
        let all = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        let pngs = all
            .filter { $0.lastPathComponent.hasPrefix(prefix + "_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        frames = pngs.compactMap { NSImage(contentsOf: $0) }
        //print("[PNG] prefix=\(prefix) frames=\(frames.count)")
    }
}

struct PNGSequencePlayerView: View {
    let folderName: String   // 这里其实当作前缀用：idle / thinking / drag
    let size: CGFloat
    let loopSeconds: Double
    
    @StateObject private var player = PNGSequencePlayer()
    @State private var frameIndex: Int = 0
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        ZStack {
            if let img = currentFrame {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Color.clear.frame(width: size, height: size)
            }
        }
        .onAppear {
            player.load(prefix: folderName)   // 关键：这里用 prefix
            frameIndex = 0
            start()
        }
        .onChange(of: folderName) { _, newValue in
            player.load(prefix: newValue)
            frameIndex = 0
            start()
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }
    
    private var currentFrame: NSImage? {
        guard !player.frames.isEmpty else { return nil }
        return player.frames[frameIndex % player.frames.count]
    }
    
    private func start() {
        cancellable?.cancel()
        cancellable = nil
        guard !player.frames.isEmpty else { return }
        
        let perFrame = max(0.1, loopSeconds / Double(player.frames.count))
        
        cancellable = Timer.publish(every: perFrame, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                frameIndex = (frameIndex + 1) % player.frames.count
            }
    }
}
