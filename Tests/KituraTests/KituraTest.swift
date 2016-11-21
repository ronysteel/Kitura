/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import XCTest
import Kitura

@testable import KituraNet

import Foundation
import Dispatch

protocol KituraTest {
    func expectation(line: Int, index: Int) -> XCTestExpectation
    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?)
}

extension KituraTest {

    func doSetUp() {
        PrintLogger.use()
    }

    func doTearDown() {
        // sleep(10)
    }

    func performServerTest(_ router: ServerDelegate, line: Int = #line,
                           asyncTasks: @escaping (XCTestExpectation) -> Void...) {

        var expectations = [XCTestExpectation]()

        for index in 0..<asyncTasks.count {
            expectations.append(self.expectation(line: line, index: index))
        }

        let exps = expectations

        Kitura.addHTTPServer(onPort: 8090, with: router)
            .started {
               let requestQueue = DispatchQueue(label: "Request queue")

               for value in zip(asyncTasks, exps) {
                   let expectation = value.1
                   requestQueue.async() {
                       value.0(expectation)
                   }
               }
        }

        Kitura.start()

        self.waitExpectation(timeout: 10) { error in
                // blocks test until request completes
                Kitura.stop()
                XCTAssertNil(error)
        }
    }

    func performRequest(_ method: String, path: String, callback: @escaping ClientRequest.Callback, headers: [String: String]? = nil, requestModifier: ((ClientRequest) -> Void)? = nil) {
        var allHeaders = [String: String]()
        if  let headers = headers {
            for  (headerName, headerValue) in headers {
                allHeaders[headerName] = headerValue
            }
        }
        if allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "text/plain"
        }
        let options: [ClientRequest.Options] =
                [.method(method), .hostname("localhost"), .port(8090), .path(path), .headers(allHeaders)]
        let req = HTTP.request(options, callback: callback)
        if let requestModifier = requestModifier {
            requestModifier(req)
        }
        req.end()
    }
}

extension XCTestCase: KituraTest {
    func expectation(line: Int, index: Int) -> XCTestExpectation {
        return self.expectation(description: "\(type(of: self)):\(line)[\(index)]")
    }

    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: t, handler: handler)
    }
}
