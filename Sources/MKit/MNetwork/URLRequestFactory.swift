//
//  NetworkWorker.swift
//  MKit
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif


enum HTTPHeaderConfiguratorType: String {
    case contentType = "Content-Type"
}

public struct URLRequestFactoryConfigurator {
    public var httpMethod: HTTPConfiguratorMethod
    public var httpServerUrlString: String
    public var httpEndpointUrlString: String
    public var httpUrlStringPath: String
    public var httpHeadParameters: [String: String]?
    public var httpBodyParameters: [String: Any?]? // json
    public var httpBodyParametersArray: [[String: Any]]? // json
    public var httpUrlQueryParameters: [String: String]?
    #if os(iOS)
    public var image: UIImage?
    #else
    public var image: NSImage?
    #endif
    public var data: Data? // form data
    public var dataKey: String?
    public var dataFileExtension: String?
    public var fileName: String?
    public var mimeType: String?
    public var cachePolicy: URLRequest.CachePolicy
    public let timeoutInterval: TimeInterval = 60 //default by Apple (https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1414063-timeoutinterval)
    public let uploadBoundary = "Boundary-\(NSUUID().uuidString)"

    // MARK: URLs

    func requestURL() -> URL {
        if let urlQuery = requestURLQuery() {
            return urlQuery
        }
        return baseURL(with: httpEndpointUrlString, pathString: httpUrlStringPath)
    }

    private func baseURL(with endpointString: String, pathString: String) -> URL {
        var url = serverURL()
        if endpointString.count > 0 {
            url.appendPathComponent(endpointString)
        }

        if pathString.count > 0 {
            url.appendPathComponent(pathString)
        }

        return url
    }

    private func serverURL() -> URL {
        return URL(string: httpServerUrlString)!
    }

    private func requestURLQuery() -> URL? {
        var urlComponents = URLComponents(url: baseURL(with: httpEndpointUrlString, pathString: httpUrlStringPath), resolvingAgainstBaseURL: true)
        if let queryParameters = httpUrlQueryParameters {
            urlComponents?.queryItems = queryParameters.enumerated().map { item in URLQueryItem(name: item.element.key, value: item.element.value) }
            return urlComponents?.url
        }
        return nil
    }

    // MARK: Http body

    func requestHttpBody() -> Data? {
        if let image = image, let imageData = image.jpegData(compressionQuality: 1.0) {
            // Upload image parameters
            let body = NSMutableData()

            httpBodyParameters?.forEach({ (key, value) in
                body.appendString("--\(uploadBoundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(String(describing: value))\r\n")
            })

            let filename = "image.jpg"
            let mimetype = "image/jpg"

            body.appendString("--\(uploadBoundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
            body.appendString("Content-Type: \(mimetype)\r\n\r\n")
            body.append(imageData)
            body.appendString("\r\n")
            body.appendString("--\(uploadBoundary)--\r\n")

            return body as Data

        } else if let data = data {
            let body = NSMutableData()

            guard let dataKey = dataKey, let fileExtension = dataFileExtension, let mime = mimeType, let fileName = fileName else { return nil }

            httpBodyParameters?.forEach({ (key, value) in
                body.appendString("--\(uploadBoundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(String(describing: value))\r\n")
            })

            body.appendString("--\(uploadBoundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(dataKey)\"; filename=\"\(fileName).\(fileExtension)\"\r\n")
            body.appendString("Content-Type: \(mime)\r\n\r\n")
            body.append(data)
            body.appendString("\r\n")
            body.appendString("--\(uploadBoundary)--\r\n")

            return body as Data

        } else {
            // Json parameters
            if let httpParamsArr = httpBodyParametersArray {
                return try? JSONSerialization.data(withJSONObject: httpParamsArr, options: [])
            }

            guard let httpParams = httpBodyParameters else { return nil }
            return try? JSONSerialization.data(withJSONObject: httpParams, options: [])
        }
    }

    // MARK: Http headers

    func allHttpHeaderFields() -> [String : String] {
        var httpHeaders = httpHeadParameters ?? [String : String]()
        httpHeaders[HTTPHeaderConfiguratorType.contentType.rawValue] = "application/json; charset=utf-8"

        return httpHeaders
    }
}

public struct URLRequestFactory {
    public var request: URLRequest
    public init(config: URLRequestFactoryConfigurator) {
        request = URLRequest(url: config.requestURL(), cachePolicy: config.cachePolicy, timeoutInterval: config.timeoutInterval)
        request.allHTTPHeaderFields = config.allHttpHeaderFields()
        request.httpMethod = config.httpMethod.rawValue
        request.httpBody = config.requestHttpBody()
    }

    public init(url: URL) {
        request = URLRequest(url: url)
    }
}


