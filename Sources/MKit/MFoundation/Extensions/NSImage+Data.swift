//
//  NSImage+Data.swift
//  MKit-mac
//
//  Created by Martin Prusa on 3/14/20.
//  Copyright © 2020 Martin Prusa. All rights reserved.
//

#if os(macOS)
import AppKit
extension NSImage {
    func jpegData(compressionQuality: Double) -> Data? {
        let _cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: _cgImage)
        let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:])
        return jpegData
    }
}
#endif
