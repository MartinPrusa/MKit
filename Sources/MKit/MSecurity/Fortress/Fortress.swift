//
//  Fortress.swift
//  MKit
//
//  Created by Martin Prusa on 4/24/20.
//

import Foundation
import CryptoKit

public final class Fortress {
    // MARK: - initialization
    public static let shared = Fortress()
    private init() { }

    // MARK: - GenericSecureValueConvertible
    public func save<T: GenericSecureValueConvertible>(genericValue: T, account: String) throws -> OSStatus {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecUseDataProtectionKeychain: true,
            kSecValueData: genericValue.dataValue
        ]

        let osStatus = SecItemAdd(query as CFDictionary, nil)

        guard osStatus == errSecSuccess else { throw FortressError("Unable to store item: \(osStatus.errMessage)") }

        return osStatus
    }

    public func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccount: account
        ]

        let osStatus = SecItemDelete(query as CFDictionary)

        switch osStatus {
            case errSecItemNotFound, errSecSuccess: break
            case let status:
                throw FortressError("Unable to delete item: \(status.errMessage)")
        }
    }

    public func value<T: GenericSecureValueConvertible>(account: String) throws -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccount: account
        ]

        var securedValue: CFTypeRef?
        let osStatus = SecItemCopyMatching(query as CFDictionary, &securedValue)
        switch osStatus {
            case errSecSuccess:
                guard let data = securedValue as? Data else { return nil }
                return try T(with: data)
            case errSecItemNotFound: return nil
            case (let status):
                throw FortressError("Unable to find item: \(status.errMessage)")
        }
    }
}
