//
//  URLSessionFactory.swift
//  MKit
//
//  Created by Martin Prusa on 8/17/19.
//

import Foundation

public final class URLSessionFactory: NSObject {
    private lazy var session: URLSession = {
        return URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue())
    }()
    private lazy var debug = DebugWorker()
    private var tasks: [URLSessionTask] = [URLSessionTask]()
    private let successfulStatusCodes = 200 ..< 300

    public static let shared = URLSessionFactory()

    private override init() {
        super.init()
    }

    public func plainLoad(resource: UrlResponseResource, completition: @escaping(_ result: Result<UrlResponseResource.ResultConstruct, UrlResponseResource.ErrorResponse>) -> Void) -> URLSessionDataTask {
        self.debug.logRequest(resource.request)

        let task = session.dataTask(with: resource.request, completionHandler: { (data, response, err) in
            if let error = err {
                self.debug.logError(error, response: response)

                let defaultErr = UrlResponseResource.ErrorResponse(response: response, err: error, data: data)

                completition(.failure(defaultErr))
                return
            }

            self.removeAllNotRunningTasks()

            self.debug.logResponse(response, data: data)
            let data = UrlResponseResource.ResultConstruct(response: response, data: data)
            completition(.success(data))
        })
        tasks.append(task)
        task.resume()

        return task
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
