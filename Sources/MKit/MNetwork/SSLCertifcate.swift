//
//  SSLCertificate.swift
//  
//
//  Created by Martin Prusa on 4/30/20.
//

import Foundation
import Security

public struct SSLCertificate {
    public let certificate: SecCertificate

    /**
     Creates representation of your DER type SSL public certificate
     - Author: Martin Prusa

     - Parameters:
         - fileName: name of the file eg when filename is (server.crt) you enter server
         - suffix: suffix of the file eg when filename is (server.crt) you enter crt

     - Returns: optional SSLCertificate when possible to create from your file name and suffix
     */
    public init?(fileName: String, suffix: String) {
        guard let cert = SecCertificateCreate().createCertificate(fileName: fileName, suffix: suffix) else { return nil }
        certificate = cert
    }
}

struct SecCertificateCreate {
    func createCertificate(fileName: String, suffix: String) -> SecCertificate? {
        do {
            guard let filePath = Bundle.main.path(forResource: fileName, ofType: suffix) else { return nil }
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return nil }
            return certificate
        } catch (let e) {
            assert(false, e.localizedDescription)
            return nil
        }
    }
}
