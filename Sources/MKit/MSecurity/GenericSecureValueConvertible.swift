//
//  GenericSecureValueConvertible.swift
//  MKit
//
//  Created by Martin Prusa on 4/25/20.
//

import Foundation

public protocol GenericSecureValueConvertible: CustomStringConvertible {
    init<T>(with contiguousBytes: T) throws where T: ContiguousBytes

    var dataValue: Data { get }
}

extension GenericSecureValueConvertible {
    public var description: String {
        return self.dataValue.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}
