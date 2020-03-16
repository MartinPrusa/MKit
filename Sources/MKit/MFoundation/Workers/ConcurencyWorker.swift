//
//  ConcurencyWorker.swift
//  MKit
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation
public final class ConcurrencyWorker {
    public static let shared = ConcurrencyWorker()

    // MARK: Background thread

    public func performOnBackgroundThread(_ block: @escaping ()->Void) {
        DispatchQueue.global(qos: .default).async(execute: block)
    }

    // MARK: Main thread
    public func performOnMainThread(_ block: @escaping ()->Void) {
        DispatchQueue.main.async(execute: block)
    }
}
