//
//  LazyDesktopAIApp.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

import SwiftUI

@main
struct LazyDesktopAIApp: App {
    @State private var pet = FloatingPetWindowController()
    @State private var setupWindow: ApiKeySetupWindowController?

    var body: some Scene {

        // 用一个“极小主窗口”触发 onAppear，负责弹 Key 配置窗
        WindowGroup {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    pet.show()

                    if (KeychainStore.load() ?? "").isEmpty {
                        setupWindow = ApiKeySetupWindowController { }
                        setupWindow?.show()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)

        // 仍然保留 Settings，方便后续修改 Key
        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lazy Desktop AI Launcher").font(.headline)

                Button("配置 / 修改 DeepSeek API Key") {
                    setupWindow = ApiKeySetupWindowController {
                        print("[KEYCHAIN] onSaved callback fired")
                    }
                    setupWindow?.show()
                }

                Button("清除已保存 Key") {
                    KeychainStore.clear()
                }

                Text("Key 存储在本机 Keychain，不会上传。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 520)
        }
    }
}
