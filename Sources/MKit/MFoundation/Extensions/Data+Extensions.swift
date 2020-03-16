//
//  Data+Exte s.swift
//  MKit-iOS
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation

public extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true) {
            self.append(data)
        }
    }
}
