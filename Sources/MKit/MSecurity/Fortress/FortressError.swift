//
//  FortressError.swift
//  MKit
//
//  Created by Martin Prusa on 4/24/20.
//

import Foundation

public struct FortressError: Error, CustomStringConvertible {
    var errMessage: String

    init(_ message: String) {
        self.errMessage = message
    }

    public var description: String {
        return errMessage
    }
}

public extension FortressError {
    var localizedDescription: String {
        return errMessage
    }
}

public extension OSStatus {
    var errMessage: String {
        guard let msg = SecCopyErrorMessageString(self, nil) as String? else { return String(self) }
        return msg
    }
}
