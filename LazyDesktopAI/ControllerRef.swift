//
//  ControllerRef.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

import Foundation
import Combine

final class ControllerRef<T: AnyObject>: ObservableObject {
    weak var value: T?
    init(_ value: T? = nil) { self.value = value }
}
