//
//  URLSessionFactory.swift
//  MKit
//
//  Created by Martin Prusa on 8/17/19.
//

import Foundation
import Combine
import X509

private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init() {}
}

private final class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, Sendable {
    private let didReceiveChallenge: @Sendable (
        URLSession,
        URLAuthenticationChallenge,
        @escaping @Sendable (
            URLSession.AuthChallengeDisposition,
            URLCredential?
        ) -> Void
    ) -> Void

    private let taskDidComplete: @Sendable (
        URLSession,
        URLSessionTask,
        Error?
    ) -> Void

    init(
        didReceiveChallenge: @escaping @Sendable (
            URLSession,
            URLAuthenticationChallenge,
            @escaping @Sendable (
                URLSession.AuthChallengeDisposition,
                URLCredential?
            ) -> Void
        ) -> Void,
        taskDidComplete: @escaping @Sendable (
            URLSession,
            URLSessionTask,
            Error?
        ) -> Void
    ) {
        self.didReceiveChallenge = didReceiveChallenge
        self.taskDidComplete = taskDidComplete
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        didReceiveChallenge(session, challenge, completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        taskDidComplete(session, task, error)
    }
}

private actor SessionState {
    var tasks: [URLSessionTask] = []
    var isSSLPiningEnabled = false
    var sslCertificate: SSLCertificate?
    var isDebugEnabled = false

    func append(_ t: URLSessionTask) { tasks.append(t) }
    func remove(id: Int) { tasks.removeAll { $0.taskIdentifier == id } }
    func removeAllNotRunning() { tasks.removeAll { $0.state != .running } }

    // config helpers
    func setDebugEnabled(_ value: Bool) { isDebugEnabled = value }
    func setSSLCertificate(_ cert: SSLCertificate?) { sslCertificate = cert }
    func setSSLPinningEnabled(_ value: Bool) { isSSLPiningEnabled = value }
}

public final class URLSessionFactory: NSObject, Sendable {
    private let backgroundQueue = OperationQueue()
    private let session: URLSession
    private let debug = DebugWorker()
    private let successfulStatusCodes = 200 ..< 300

    public static let shared = URLSessionFactory()
    private let delegate: SessionDelegate
    private let state = SessionState()

    // MARK: - Public configuration (async, actor-backed)

    public func setDebugEnabled(_ newValue: Bool) async {
        await state.setDebugEnabled(newValue)
    }

    public func debugEnabled() async -> Bool {
        await state.isDebugEnabled
    }

    public func setSSLCertificate(_ cert: SSLCertificate?) async {
        await state.setSSLCertificate(cert)
    }

    public func currentSSLCertificate() async -> SSLCertificate? {
        await state.sslCertificate
    }

    private override init() {
        // Build delegate without capturing `self` before super.init
        let owner = WeakBox<URLSessionFactory>()
        self.delegate = SessionDelegate(
            didReceiveChallenge: { [owner] _, challenge, completion in
                guard let strong = owner.value else {
                    completion(.performDefaultHandling, nil)
                    return
                }
                Task { await strong.handle(challenge: challenge, completion: completion) }
            },
            taskDidComplete: { [owner] _, task, _ in
                guard let strong = owner.value else { return }
                Task { await strong.state.remove(id: task.taskIdentifier) }
            }
        )

        self.session = URLSession(configuration: .default,
                                  delegate: delegate,
                                  delegateQueue: backgroundQueue)
        super.init()
        owner.value = self
    }

    private func handle(challenge: URLAuthenticationChallenge,
                        completion: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) async {
        let pinning = await state.isSSLPiningEnabled
        guard pinning else {
            completion(.performDefaultHandling, nil)
            return
        }

        guard
            let serverTrust = challenge.protectionSpace.serverTrust,
            let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
            let secCertificate = certificates.first,
            let remoteCertificate = try? Certificate(secCertificate)
        else {
            completion(.performDefaultHandling, nil)
            return
        }

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            let policies = NSMutableArray()
            policies.add(SecPolicyCreateSSL(true, (challenge.protectionSpace.host as CFString)))
            SecTrustSetPolicies(serverTrust, policies)

            var error: CFError? = nil
            let isServerTrusted = SecTrustEvaluateWithError(serverTrust, &error)

            let localCert = await state.sslCertificate
            guard
                isServerTrusted,
                let sslCertificate = localCert,
                let secCertificate = sslCertificate.createCertificate(),
                let localCertificate = try? Certificate(secCertificate)
            else {
                completion(.cancelAuthenticationChallenge, nil)
                return
            }

            if remoteCertificate.issuer == localCertificate.issuer {
                let credential = URLCredential(trust: serverTrust)
                completion(.useCredential, credential)
            } else {
                completion(.cancelAuthenticationChallenge, nil)
            }

        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM,
             NSURLAuthenticationMethodNegotiate, NSURLAuthenticationMethodClientCertificate:
            guard challenge.previousFailureCount == 0 else {
                completion(.rejectProtectionSpace, nil)
                return
            }
            completion(.performDefaultHandling, nil)

        default:
            completion(.performDefaultHandling, nil)
        }
    }

    public func plainLoadPublisher(resource: UrlResponseResource) -> AnyPublisher<UrlResponseResource.ResultConstruct, UrlResponseResource.ErrorResponse> {
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

    public func plainLoadDecodedPublisher<T: Decodable>(resource: UrlResponseResource, decodable: T.Type, customDecoder: JSONDecoder? = nil) -> AnyPublisher<T, UrlResponseResource.ErrorResponse> {

        return session.dataTaskPublisher(for: resource.request)
            .tryMap({ (data, response) -> Data in
                if let response = response as? HTTPURLResponse, self.successfulStatusCodes.contains(response.statusCode) == false {
                    throw UrlResponseResource.ErrorResponse(response: response, err: nil, data: data)
                }

                return data
            })
            .decode(type: decodable, decoder: customDecoder ?? JSONDecoder())
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

    public func plainLoadDecoded<T: Decodable>(resource: UrlResponseResource, decodable: T.Type, customDecoder: JSONDecoder? = nil) async throws(UrlResponseResource.ErrorResponse) -> T {
        do {
            if await self.debugEnabled() {
                 self.debug.logRequest(resource.request)
            }

            let (data, response) = try await session.data(for: resource.request, delegate: delegate)
            guard
                let urlResponse = response as? HTTPURLResponse
            else {
                throw UrlResponseResource.ErrorResponse.unknownError
            }
            let decoder = customDecoder ?? JSONDecoder()
            guard let decoded = try? decoder.decode(decodable, from: data) else {
                throw UrlResponseResource.ErrorResponse(response: urlResponse, err: nil, data: data)
            }
            return decoded
        } catch(let error) {
            throw UrlResponseResource.ErrorResponse(response: nil, err: error as NSError, data: nil)
        }
    }

    public func plainLoad(resource: UrlResponseResource) async throws(UrlResponseResource.ErrorResponse) -> UrlResponseResource.ResultConstruct {
        do {
            if await self.debugEnabled() {
                 self.debug.logRequest(resource.request)
            }

            let (data, response) = try await session.data(for: resource.request, delegate: delegate)
            guard
                let urlResponse = response as? HTTPURLResponse
            else {
                if await self.debugEnabled() {
                     self.debug.logError(UrlResponseResource.ErrorResponse.unknownError, response: response)
                }

                throw UrlResponseResource.ErrorResponse.unknownError
            }

            if await self.debugEnabled() {
                 self.debug.logResponse(urlResponse, data: data)
            }

            return UrlResponseResource.ResultConstruct(response: response, data: data)
        } catch(let error) {
            if await self.debugEnabled() {
                 self.debug.logError(error, response: nil)
            }
            throw UrlResponseResource.ErrorResponse(response: nil, err: error as NSError, data: nil)
        }
    }

    deinit {
        //to release the delegate strong reference
        session.finishTasksAndInvalidate()
    }
}

extension URLSessionFactory {
    public func cancelAllTasks() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}
