//
//  UrlResponseResource.swift
//  MKit
//
//  Created by Martin Prusa on 7/29/19.
//

import Foundation

public struct UrlResponseResource {
    public let request: URLRequest
    public let result: Result<ResultConstruct, ErrorResponse>?
    public let isSslPinningEnabled: Bool

    public init(request: URLRequest, result: Result<ResultConstruct, ErrorResponse>?, isSslPinningEnabled: Bool = false) {
        self.request = request
        self.result = result
        self.isSslPinningEnabled = isSslPinningEnabled
    }

    public struct ResultConstruct: Serializable {
        public var response: URLResponse?
        public var data: Data?

        public init(response: URLResponse?, data: Data?) {
            self.response = response
            self.data = data
        }
    }

    public struct ErrorResponse: Error, Serializable {
        public let response: URLResponse?
        public let err: Error?
        public var data: Data?

        public init(response: URLResponse?, err: Error?, data: Data?) {
            self.response = response
            self.err = err
            self.data = data
        }
    }
}
