//
//  File.swift
//  MKit-mac
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation
import AppKit
extension NSImage {
    func jpegData(compressionQuality: Double) -> Data? {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:])
        return jpegData
    }
}

