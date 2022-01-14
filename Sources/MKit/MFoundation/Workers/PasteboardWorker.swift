//
//  PasteboardWorker.swift
//  
//
//  Created by Martin Prusa on 14.01.2022.
//

import Foundation
import UIKit

public struct PasteboardWorker {
    private let pasteboard: UIPasteboard

    public init(pasteboard: UIPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func set(text: String) {
        pasteboard.string = text
    }

    public func text() -> String? {
        pasteboard.string
    }
}
