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
    private var cancelables: [String: AnyCancellable] = [String: AnyCancellable]()
    private let successfulStatusCodes = 200 ..< 300

    public static let shared = URLSessionFactory()
    public var isDebugEndabled = false

    private override init() {
        super.init()
    }

    @discardableResult
    public func plainLoad(resource: UrlResponseResource, completition: @escaping(_ result: Result<UrlResponseResource.ResultConstruct, UrlResponseResource.ErrorResponse>) -> Void) -> URLSessionDataTask {
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

    public func plainLoadDecoded<T: Decodable>(resource: UrlResponseResource, decodable: T.Type, completion: @escaping(T?, Error?) -> Void) {
        let cancelable = session.dataTaskPublisher(for: resource.request)
            .map{ $0.data }
            .receive(on: RunLoop.main)
            .decode(type: decodable, decoder: JSONDecoder())
            .eraseToAnyPublisher()
            .sink(receiveCompletion: { err in
                self.cancelables.removeValue(forKey: resource.request.url!.absoluteString)
                switch err {
                    case .failure(let error):
                        completion(nil, error)
                    default:
                        completion(nil, nil)
                }
            }) { value in
                self.cancelables.removeValue(forKey: resource.request.url!.absoluteString)
                completion(value, nil)
            }

        cancelables[resource.request.url!.absoluteString] = cancelable
    }

    public func plainLoadDecodedPublisher<T: Decodable>(resource: UrlResponseResource, decodable: T.Type) -> AnyPublisher<T, UrlResponseResource.ErrorResponse> {
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
        cancelables.removeAll()
    }
}

extension URLSessionFactory {
    public func cancelAllTasks() {
        cancelables.forEach({ $1.cancel() })
        cancelables.removeAll()

        guard tasks.isEmpty == false else { return }
        tasks.forEach({ $0.cancel() })
    }

    fileprivate func removeAllNotRunningTasks() {
        guard tasks.isEmpty == false else { return }
        tasks.removeAll(where: { $0.state != .running })
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
