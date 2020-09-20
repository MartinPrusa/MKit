//
//  GenericSecureValue.swift
//  MKit
//
//  Created by Martin Prusa on 4/25/20.
//

import Foundation

public enum GenericSecureValueError: Error {
    case cannotReachBaseAddress
    case cannotCreateDataFromUnsafeBytes
    case cannotConvertStringToData
    case cannotCreateGenericSecureValueFromString
}

extension GenericSecureValueError {
    public var localizedDescription: String {
        return description
    }
}

extension GenericSecureValueError: CustomStringConvertible {
    public var description: String {
        switch self {
            case .cannotReachBaseAddress:
                return "baseAddress: UnsafeRawPointer is nil in UnsafeRawBufferPointer"
            case .cannotCreateDataFromUnsafeBytes:
                return "withUnsafeBytes in ContiguousBytes protocol is unable to return value"
            case .cannotConvertStringToData:
                return "withUnsafeBytes in ContiguousBytes protocol is unable to return value"
            case .cannotCreateGenericSecureValueFromString:
                return "string protocol init fails to create GenericSecureValue"
        }
    }
}

public struct GenericSecureValue: GenericSecureValueConvertible {
    public var dataValue: Data

    public init<T>(string pwd: T) throws where T: StringProtocol {
        do {
            guard let pwdData = pwd.data(using: .utf8) else { throw GenericSecureValueError.cannotConvertStringToData }
            try self.init(with: pwdData)
        } catch {
            throw GenericSecureValueError.cannotCreateGenericSecureValueFromString
        }
    }

    public init<T>(with contiguousBytes: T) throws where T : ContiguousBytes {
        do {
            let value = try contiguousBytes.withUnsafeBytes { unsafeBytes -> Data in
                guard let rawPointer = unsafeBytes.baseAddress else { throw GenericSecureValueError.cannotReachBaseAddress }
                return Data(bytes: rawPointer, count: unsafeBytes.count)
            }

            dataValue = value
        } catch {
            throw GenericSecureValueError.cannotCreateDataFromUnsafeBytes
        }
    }
}
