//
//  DebugWorker.swift
//  MKit
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation
public struct DebugWorker {
    let isDebug: Bool = {
        var isDebug = false
        // function with a side effect and Bool return value that we can pass into assert()
        func set(debug: Bool) -> Bool {
            isDebug = debug
            return isDebug
        }
        // assert:
        // "Condition is only evaluated in playgrounds and -Onone builds."
        // so isDebug is never changed to true in Release builds
        assert(set(debug: true))
        return isDebug
    }()

    public init() {

    }

    // MARK: Log networking

    public func logRequest(_ request: URLRequest) {
        if self.isDebug {
            print("Request: \(request) - (\(String(describing: request.httpMethod)))")
            print("Request headers: \(request.allHTTPHeaderFields as AnyObject)")

            guard let data = request.httpBody else { return }
            try? print("Request body: \(JSONSerialization.jsonObject(with: data, options: []) as AnyObject))")
        }
    }

    public func logError(_ error: Error, response: URLResponse?) {
        if self.isDebug {
            if let response = response {
                print("🔴 Error (\(String(describing: response.url))): \(error.localizedDescription)")
            } else {
                print("🔴 Error: \(error.localizedDescription)")
            }

        }
    }

    public func logResponse(_ response: URLResponse?, data: Data?) {
        if self.isDebug {
            guard let data = data, let response = response else { return }

            let statusCode = String(describing: (response as? HTTPURLResponse)?.statusCode)
            let responseUrl = String(describing: response.url)

            print("---------")
            print("Response: Status = \(statusCode), \(responseUrl)")
            print("Response headers: \((response as? HTTPURLResponse)?.allHeaderFields as AnyObject)")

            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ Response JSON: \(jsonString)")
            }

            print("\n\n")
        }
    }

    public func log(_ string: String) {
        if isDebug {
            print(string)
        }
    }
}
