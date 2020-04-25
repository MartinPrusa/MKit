//
//  LAService.swift
//  
//
//  Created by Martin Prusa on 4/25/20.
//

import Foundation
import LocalAuthentication

public enum BiometryOnDeviceType {
    case notAvailable
    case notEnrolled
    case faceID
    case touchID
}

public final class LAServiceFactory {
    public static var context: LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        return context
    }
}

public final class LAService {
    public static let shared = LAService()

    private let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
    private let reason = "Authenticate yourself!"

    public var biometryByPolicyOnDevice: BiometryOnDeviceType {
        return checkBiometryTypeOnDevice()
    }

    private init() { }

    private func checkBiometryTypeOnDevice() -> BiometryOnDeviceType {
        let context = LAServiceFactory.context
        var authError: NSError? = nil

        if context.canEvaluatePolicy(policy, error: &authError) {
            let type: LABiometryType = context.biometryType
            switch type {
                case .faceID:
                    return .faceID
                case .touchID:
                    return .touchID
                default:
                    return .notAvailable
            }
        }

        return (authError!.code == kLAErrorBiometryNotEnrolled) ? .notEnrolled : .notAvailable
    }
}

// MARK: - Login local authentication

public enum BiometricPolicyState {
    case systemCancel
    case userFallBack
    case userCancel
    case failed
    case success
}

public extension LAService {
    func evaluateLoginBiometricPolicy(fallbackTitle: String? = nil, completion: @escaping(BiometricPolicyState) -> Void) {
        let context = LAServiceFactory.context
        context.localizedFallbackTitle = fallbackTitle

        context.evaluatePolicy(policy, localizedReason: reason) { (success, error) in
            if let error = error as NSError? {
                switch error.code {
                    case LAError.Code.systemCancel.rawValue:
                        completion(.systemCancel)

                    case LAError.Code.userCancel.rawValue:
                        completion(.userCancel)

                    case LAError.Code.userFallback.rawValue:
                        completion(.userFallBack)

                    default:
                        completion(.failed)
                }
            } else {
                completion(.success)
            }
        }
    }
}
