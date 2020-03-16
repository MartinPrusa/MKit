//
//  EndpointTarget.swift
//  MKit
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation

//// The protocol used to define the API endpoint
public protocol EndpointTarget {
    var serverUrlString: String { get }

    /// The endpoint's base string path
    var urlString: String { get }

    /// The method used to create request factory for networking
    func requestFactoryConfigurator() -> URLRequestFactoryConfigurator

    func httpHeadParameters() -> [String : String]
}

/// Extension used to define basic request configuration
extension EndpointTarget {
    /// Creates basic request factory configurator with default values which can be changed for each target and endpoint
    public func baseRequestFactoryConfigurator() -> URLRequestFactoryConfigurator {
        return URLRequestFactoryConfigurator(
            httpMethod: .get,
            httpServerUrlString: self.serverUrlString,
            httpEndpointUrlString: self.urlString,
            httpUrlStringPath: "",
            httpHeadParameters: self.httpHeadParameters(),
            httpBodyParameters: nil,
            httpBodyParametersArray: nil,
            httpUrlQueryParameters: nil,
            image: nil,
            data: nil,
            dataKey: nil,
            dataFileExtension: nil,
            fileName: nil,
            mimeType: nil,
            cachePolicy: .useProtocolCachePolicy
        )
    }

    /// Returns saved API http headers
    public func httpHeadParameters() -> [String : String] {
        return [String: String]()
    }
}
