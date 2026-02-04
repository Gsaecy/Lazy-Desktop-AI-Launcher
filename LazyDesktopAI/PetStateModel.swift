//
//  PetStateModel.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//
import Foundation
import Combine

@MainActor
final class PetStateModel: ObservableObject {
    @Published var state: PetState = .idle
}
