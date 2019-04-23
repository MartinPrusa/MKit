//
//  NetworkWorker.swift
//  MKit
//
//  Created by Martin Prusa on 4/23/19.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct ErrorResponse: Error {
    public let response: URLResponse?
    public let err: Error?

    public init(response: URLResponse?, err: Error?) {
        self.response = response
        self.err = err
    }
}
//----- MODEL -----//
public struct PlainResource {
    public let request: URLRequest
    public let result: Result<Data, NSError>?

    public init (request: URLRequest, result: Result<Data, NSError>? = nil) {
        self.request = request
        self.result = result
    }
}

public struct UrlResponseResource {
    public let request: URLRequest
    public let result: Result<ResultConstruct, ErrorResponse>?

    public init(request: URLRequest, result: Result<ResultConstruct, ErrorResponse>?) {
        self.request = request
        self.result = result
    }

    public struct ResultConstruct {
        public var response: URLResponse?
        public var data: Data?
    }
}

public struct Resource<T> {
    let request: URLRequest
    let parse: (Data) throws -> T?
}

extension Resource where T: Decodable {
    public init(request: URLRequest) {
        self.request = request
        self.parse = { data in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(T.self, from: data)
        }
    }
}

//----- URLSession -----//
public enum HTTPConfiguratorMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}

enum HTTPHeaderConfiguratorType: String {
    case contentType = "Content-Type"
}

public struct URLRequestFactoryConfigurator {
    public var httpMethod: HTTPConfiguratorMethod
    public var httpServerUrlString: String
    public var httpEndpointUrlString: String
    public var httpUrlStringPath: String
    public var httpHeadParameters: [String : String]?
    public var httpBodyParameters: [String : Any?]? // json
    public var httpBodyParametersArray: [[String : Any]]? // json
    public var httpUrlQueryParameters: [String: String]?
    #if os(macOS)
    public var image: NSImage?
    #else
    public var image: UIImage?
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
        //        httpHeaders[HTTPHeaderConfiguratorType.contentType.rawValue] = (image != nil || data != nil) ? "multipart/form-data; boundary=\(uploadBoundary)" : "application/json; charset=utf-8"

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

public final class URLSessionFactory: NSObject {
    var session: URLSession!
    let backgroundQueue = OperationQueue()
    private lazy var debug = DebugWorker()
    private let successfulStatusCodes = 200 ..< 300

    public override init() {
        super.init()

        session = URLSession(configuration: URLSessionConfiguration.default,
                             delegate: self,
                             delegateQueue: backgroundQueue)
        //        session = URLSession.shared
    }

    public func load<T>(resource: Resource<T>, completion: @escaping (T?, _ err: ErrorResponse?) -> Void) {
        self.debug.logRequest(resource.request)

        session.dataTask(with: resource.request, completionHandler: { (data, response, err) in
            guard let data = data else {
                self.debug.logError(err!, response: response)
                completion(nil, self.parseError(response: response, error: err, data: nil))
                return
            }

            self.debug.logResponse(response, data: data)

            do {
                let parsedData = try resource.parse(data)
                completion(parsedData, nil)
            } catch (let decodeErr) {
                self.debug.logError(decodeErr, response: nil)
                completion(nil, self.parseError(response: response, error: decodeErr, data: data))
            }

        }).resume()
    }

    public func plainLoad(resource: UrlResponseResource, completition: @escaping(_ result: Result<UrlResponseResource.ResultConstruct, ErrorResponse>) -> Void) -> URLSessionDataTask {
        self.debug.logRequest(resource.request)

        let task = session.dataTask(with: resource.request, completionHandler: { (data, response, err) in
            if let error = err {
                self.debug.logError(error, response: response)

                let defaultErr = ErrorResponse.init(response: response, err: error)

                completition(.failure(defaultErr))
                return
            }

            self.debug.logResponse(response, data: data)
            let data = UrlResponseResource.ResultConstruct.init(response: response, data: data)
            completition(.success(data))
        })
        task.resume()
        return task
    }

    public func plainLoad(resource: PlainResource, completion: @escaping (_ result: Result<Data, NSError>) -> Void) {
        session.dataTask(with: resource.request, completionHandler: { (data, response, error) in
            let result: Result<Data, NSError>
            if let err = error {
                let error = NSError.init(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: err.localizedDescription])
                result = .failure(error)
                DispatchQueue.main.async {
                    completion(result)
                }
                return
            }

            result = .success(data!)
            DispatchQueue.main.async {
                completion(result)
            }
        }).resume()
    }

    private func parseError(response: URLResponse?, error: Error?, data: Data?) -> ErrorResponse? {
        if error?.localizedDescription == "cancelled" { return nil }
        return ErrorResponse.init(response: response, err: error)
    }

    deinit {
        //to release the delegate strong reference
        session.finishTasksAndInvalidate()
    }
}

extension URLSessionFactory: URLSessionDelegate {

}

extension URLSessionFactory: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
