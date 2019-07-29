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

    public init(request: URLRequest, result: Result<ResultConstruct, ErrorResponse>?) {
        self.request = request
        self.result = result
    }

    public struct ResultConstruct: Serializable {
        public var response: URLResponse?
        public var data: Data?
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
