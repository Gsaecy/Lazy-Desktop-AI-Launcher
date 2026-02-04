//
//  PetState.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

import Foundation

enum PetState {
    case idle
    case thinking
    case dragging

    var assetFolder: String {
        switch self {
        case .idle: return "idle"
        case .thinking: return "thinking"
        case .dragging: return "drag"
        }
    }
}
