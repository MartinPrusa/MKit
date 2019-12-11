//
//  NetworkTest.swift
//  MKitTests-iOS
//
//  Created by Martin Prusa on 12/11/19.
//

import XCTest

final class NetworkTest: XCTestCase {
    var resource: UrlResponseResource!

    override func setUp() {
        let target = Target.sample
        let requestFactory = URLRequestFactory(config: target.requestFactoryConfigurator())
        resource = UrlResponseResource(request: requestFactory.request, result: nil)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // Create an expectation for a background download task.
        let expectation = XCTestExpectation(description: "Download JSON file")

        URLSessionFactory.shared.plainLoad(resource: resource) { result in
            print(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
}

enum Target: EndpointTarget {
    case sample

    var serverUrlString: String {
        return "https://www.learningcontainer.com"
    }

    var urlString: String {
        return "/bfd_download"
    }

    func requestFactoryConfigurator() -> URLRequestFactoryConfigurator {
        var configurator = baseRequestFactoryConfigurator()
        configurator.httpUrlStringPath = "/json-sample/"

        return configurator
    }
}
