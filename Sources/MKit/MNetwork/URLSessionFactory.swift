//
//  URLSessionFactory.swift
//  MKit
//
//  Created by Martin Prusa on 8/17/19.
//

import Foundation
import Combine

public final class URLSessionFactory: NSObject {
    private let backgroundQueue = OperationQueue()
    private lazy var session: URLSession = {
        return URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: backgroundQueue)
    }()
    private lazy var debug = DebugWorker()
    private var tasks: [URLSessionTask] = [URLSessionTask]()
    private let successfulStatusCodes = 200 ..< 300

    public static let shared = URLSessionFactory()
    public var isDebugEndabled = false
    private var isSSLPiningEnabled = false
    public var sslCertificate: SSLCertificate?
    private var isRemovingAllNotRunningTasks = false

    private override init() {
        super.init()
    }

    @discardableResult
    public func plainLoad(resource: UrlResponseResource, completition: @escaping(_ result: Result<UrlResponseResource.ResultConstruct, UrlResponseResource.ErrorResponse>) -> Void) -> URLSessionDataTask {
        isSSLPiningEnabled = resource.isSslPinningEnabled

        if self.isDebugEndabled == true {
            self.debug.logRequest(resource.request)
        }

        let task = session.dataTask(with: resource.request, completionHandler: { (data, response, err) in
            if let error = err {
                if self.isDebugEndabled == true {
                    self.debug.logError(error, response: response)
                }

                let defaultErr = UrlResponseResource.ErrorResponse(response: response, err: error, data: data)

                completition(.failure(defaultErr))
                return
            }

            self.removeAllNotRunningTasks()

            if self.isDebugEndabled == true {
                self.debug.logResponse(response, data: data)
            }

            let data = UrlResponseResource.ResultConstruct(response: response, data: data)

            completition(.success(data))
        })
        tasks.append(task)
        task.resume()

        return task
    }

    public func plainLoadPublisher(resource: UrlResponseResource) -> AnyPublisher<UrlResponseResource.ResultConstruct, UrlResponseResource.ErrorResponse> {
        isSSLPiningEnabled = resource.isSslPinningEnabled

        return session.dataTaskPublisher(for: resource.request)
            .tryMap({ (data, response) -> UrlResponseResource.ResultConstruct in
                if let response = response as? HTTPURLResponse, self.successfulStatusCodes.contains(response.statusCode) == false {
                    throw UrlResponseResource.ErrorResponse(response: response, err: nil, data: data)
                }

                return UrlResponseResource.ResultConstruct(response: response, data: data)
            })
            .mapError({ error -> UrlResponseResource.ErrorResponse in
                if let err = error as? UrlResponseResource.ErrorResponse {
                    return err
                } else {
                    return UrlResponseResource.ErrorResponse(response: nil, err: error, data: nil)
                }
            })
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func plainLoadDecodedPublisher<T: Decodable>(resource: UrlResponseResource, decodable: T.Type) -> AnyPublisher<T, UrlResponseResource.ErrorResponse> {
        isSSLPiningEnabled = resource.isSslPinningEnabled

        return session.dataTaskPublisher(for: resource.request)
            .tryMap({ (data, response) -> Data in
                if let response = response as? HTTPURLResponse, self.successfulStatusCodes.contains(response.statusCode) == false {
                    throw UrlResponseResource.ErrorResponse(response: response, err: nil, data: data)
                }

                return data
            })
            .decode(type: decodable, decoder: JSONDecoder())
            .mapError({ error -> UrlResponseResource.ErrorResponse in
                if let err = error as? UrlResponseResource.ErrorResponse {
                    return err
                } else {
                    return UrlResponseResource.ErrorResponse(response: nil, err: error, data: nil)
                }
            })
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    deinit {
        //to release the delegate strong reference
        session.finishTasksAndInvalidate()
    }
}

extension URLSessionFactory {
    public func cancelAllTasks() {
        guard tasks.isEmpty == false else { return }
        tasks.forEach({ $0.cancel() })
    }

    fileprivate func removeAllNotRunningTasks() {
        guard isRemovingAllNotRunningTasks == false else { return }
        guard tasks.isEmpty == false else { return }
        isRemovingAllNotRunningTasks = true
        tasks.removeAll(where: { $0.state != .running })
        isRemovingAllNotRunningTasks = false
    }

    fileprivate func removeTask(by identifier: Int) {
        guard tasks.isEmpty == false else { return }
        tasks.removeAll(where: { $0.taskIdentifier == identifier })
    }
}

extension URLSessionFactory: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        removeTask(by: task.taskIdentifier)
    }
}

extension URLSessionFactory: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard isSSLPiningEnabled == true else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust, let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:

                // Set SSL policies for domain name check
                let policies = NSMutableArray()
                policies.add(SecPolicyCreateSSL(true, (challenge.protectionSpace.host as CFString)))
                SecTrustSetPolicies(serverTrust, policies)

                // Evaluate server certificate
                var error: CFError? = nil
                let isServerTrusted = SecTrustEvaluateWithError(serverTrust, &error)

                guard let sslCertificate = sslCertificate else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                    return
                }

                // Get remote certification data
                let remoteCertificateData: Data = SecCertificateCopyData(certificate) as Data
                let localCertificateData: Data = SecCertificateCopyData(sslCertificate.certificate) as Data

                if isServerTrusted == true, remoteCertificateData == localCertificateData {
                    let credential:URLCredential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }

            case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM,
                   NSURLAuthenticationMethodNegotiate, NSURLAuthenticationMethodClientCertificate:
                guard challenge.previousFailureCount == 0 else {
                    completionHandler(.rejectProtectionSpace, nil)
                    return
                }

                completionHandler(.performDefaultHandling, nil)
            default:
                completionHandler(.performDefaultHandling, nil)
        }
    }
}
