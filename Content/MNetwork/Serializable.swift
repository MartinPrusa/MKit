//
//  Serializable.swift
//  MKit-iOS
//
//  Created by Martin Prusa on 7/29/19.
//

import Foundation

public protocol Serializable {
    var data: Data? { get }
    func serialize<T:Decodable>() throws -> T?
}

public extension Serializable {
    func serialize<T:Decodable>() throws -> T? {
        guard let data = data else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(T.self, from: data)
    }
}
