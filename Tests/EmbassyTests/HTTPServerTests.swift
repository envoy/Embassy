//
//  HTTPServerTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Dispatch
import XCTest

@testable import Embassy

#if os(Linux)
    extension HTTPServerTests {
        static var allTests = [
            ("testEnviron", testEnviron),
            ("testStartResponse", testStartResponse),
            ("testSendBody", testSendBody),
            ("testAsyncSendBody", testAsyncSendBody),
            ("testPostBody", testPostBody),
            ("testPostWithInitialBody", testPostWithInitialBody),
            ("testAddressReuse", testAddressReuse),
            ("testStopAndWait", testStopAndWait),
        ]
    }
#endif

class HTTPServerTests: XCTestCase {
    let queue = DispatchQueue(label: "com.envoy.embassy-tests.http-server", attributes: [])
    var loop: SelectorEventLoop!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        loop = try! SelectorEventLoop(selector: try! TestingSelector())

        let sessionConfig = URLSessionConfiguration.default
        session = URLSession(configuration: sessionConfig)
        // set a 30 seconds timeout
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(30 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            if self.loop.running {
                self.loop.stop()
                XCTFail("Time out")
            }
        }
    }

    override func tearDown() {
        super.tearDown()
    }

    func testEnviron() {
        let port = try! getUnusedTCPPort()
        var receivedEnviron: [String: Any]!
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: ((Data) -> Void)
            ) in
            receivedEnviron = environ
            self.loop.stop()
        }

        try! server.start()

        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            let task = self.session.dataTask(
                with: URL(string: "http://[::1]:\(port)/path?foo=bar")!
            )
            task.resume()
        }

        loop.runForever()

        XCTAssertEqual(receivedEnviron["REQUEST_METHOD"] as? String, "GET")
        XCTAssertEqual(receivedEnviron["HTTP_HOST"] as? String, "[::1]:\(port)")
        XCTAssertEqual(receivedEnviron["SERVER_PROTOCOL"] as? String, "HTTP/1.1")
        XCTAssertEqual(receivedEnviron["SERVER_PORT"] as? String, String(port))
        XCTAssertEqual(receivedEnviron["SCRIPT_NAME"] as? String, "")
        XCTAssertEqual(receivedEnviron["PATH_INFO"] as? String, "/path")
        XCTAssertEqual(receivedEnviron["QUERY_STRING"] as? String, "foo=bar")
        XCTAssertEqual(receivedEnviron["swsgi.version"] as? String, "0.1")
        XCTAssertEqual(receivedEnviron["swsgi.multithread"] as? Bool, false)
        XCTAssertEqual(receivedEnviron["swsgi.multiprocess"] as? Bool, false)
        XCTAssertEqual(receivedEnviron["swsgi.url_scheme"] as? String, "http")
        XCTAssertEqual(receivedEnviron["swsgi.run_once"] as? Bool, false)
        XCTAssertNotNil(receivedEnviron["embassy.connection"] as? HTTPConnection)
        XCTAssertNotNil(receivedEnviron["embassy.event_loop"] as? EventLoop)
        XCTAssertNotNil(receivedEnviron["embassy.version"] as? String)
    }

    func testStartResponse() {
        let port = try! getUnusedTCPPort()
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: ((Data) -> Void)
            ) in
            startResponse("451 Big brother doesn't like this", [
                ("Content-Type", "video/porn"),
                ("Server", "Embassy-by-envoy"),
                ("X-Foo", "Bar"),
            ])
            sendBody(Data())
        }

        try! server.start()

        var receivedData: Data?
        var receivedResponse: HTTPURLResponse?
        var receivedError: NSError?
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            let task = self.session.dataTask(with: URL(string: "http://[::1]:\(port)")!, completionHandler: { (data, response, error) in
                receivedData = data
                receivedResponse = response as? HTTPURLResponse
                receivedError = error as NSError?
                self.loop.stop()
            })
            task.resume()
        }

        loop.runForever()

        XCTAssertEqual(receivedData?.count, 0)
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 451)
        // XXX
        /*
        XCTAssertEqual(receivedResponse?.allHeaderFields["Content-Type"], "video/porn")
        XCTAssertEqual(receivedResponse?.allHeaderFields["Server"], "Embassy-by-envoy")
        XCTAssertEqual(receivedResponse?.allHeaderFields["X-Foo"], "Bar")*/
    }

    func testSendBody() {
        let port = try! getUnusedTCPPort()
        let bigDataChunk = Data(makeRandomString(574300).utf8)
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: ((Data) -> Void)
            ) in
            startResponse("200 OK", [])
            sendBody(bigDataChunk)
            sendBody(Data())
        }

        try! server.start()

        var receivedData: Data?
        var receivedResponse: HTTPURLResponse?
        var receivedError: NSError?
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            let task = self.session.dataTask(with: URL(string: "http://[::1]:\(port)")!, completionHandler: { (data, response, error) in
                receivedData = data
                receivedResponse = response as? HTTPURLResponse
                receivedError = error as NSError?
                self.loop.stop()
            })
            task.resume()
        }

        loop.runForever()

        let data = receivedData ?? Data()
        XCTAssertEqual(receivedData?.count, bigDataChunk.count)
        XCTAssertEqual(data, bigDataChunk)
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 200)
    }

    func testAsyncSendBody() {
        let port = try! getUnusedTCPPort()
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: @escaping ((String, [(String, String)]) -> Void),
                sendBody: @escaping ((Data) -> Void)
            ) in
            startResponse("200 OK", [])

            let loop = environ["embassy.event_loop"] as! EventLoop

            loop.call(withDelay: 1) {
                sendBody(Data("hello ".utf8))
            }
            loop.call(withDelay: 2) {
                sendBody(Data("baby ".utf8))
            }
            loop.call(withDelay: 3) {
                sendBody(Data("fin".utf8))
                sendBody(Data())
            }
        }

        try! server.start()

        var receivedData: Data?
        var receivedResponse: HTTPURLResponse?
        var receivedError: NSError?
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            let task = self.session.dataTask(with: URL(string: "http://[::1]:\(port)")!, completionHandler: { (data, response, error) in
                receivedData = data
                receivedResponse = response as? HTTPURLResponse
                receivedError = error as NSError?
                self.loop.stop()
            })
            task.resume()
        }

        loop.runForever()

        XCTAssertEqual(NSString(data: receivedData!, encoding: String.Encoding.utf8.rawValue)!, "hello baby fin")
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 200)
    }

    func testPostBody() {
        let port = try! getUnusedTCPPort()

        let postBodyString = makeRandomString(40960)
        var receivedInputData: [Data] = []
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: @escaping ((Data) -> Void)
            ) in
            if environ["HTTP_EXPECT"] as? String == "100-continue" {
                startResponse("100 Continue", [])
            } else {
                startResponse("200 OK", [])
            }
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                receivedInputData.append(data)
                sendBody(data)
            }
        }

        try! server.start()

        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            var request = URLRequest(url: URL(string: "http://[::1]:\(port)")!)
            request.httpMethod = "POST"
            request.httpBody = postBodyString.data(using: String.Encoding.utf8)
            let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
                self.loop.stop()
            })
            task.resume()
        }

        loop.runForever()

        // ensure EOF is passed
        XCTAssertEqual(receivedInputData.last?.count, 0)

        let receivedString = String(bytes: receivedInputData.joined(separator: []), encoding: String.Encoding.utf8)
        XCTAssertEqual(receivedString, postBodyString)
    }

    func testPostWithInitialBody() {
        let port = try! getUnusedTCPPort()

        // this chunk is small enough, ideally should be sent along with header (initial body)
        let postBodyString = "hello"
        var receivedInputData: [Data] = []
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: @escaping ((Data) -> Void)
            ) in
            if environ["HTTP_EXPECT"] as? String == "100-continue" {
                // Notice: under linux, it seems the underlying URLSession implementation (cURL in
                // this case I guess), will send Expect: 100-continue, we need to reply
                // 100 Continue so that it will continue sending body
                startResponse("100 Continue", [])
            } else {
                startResponse("200 OK", [])
            }
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                receivedInputData.append(data)
                sendBody(data)
            }
        }

        try! server.start()

        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            var request = URLRequest(url: URL(string: "http://[::1]:\(port)")!)
            request.httpMethod = "POST"
            request.httpBody = postBodyString.data(using: String.Encoding.utf8)
            let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
              self.loop.stop()
            })
            task.resume()
        }

        loop.runForever()

        // ensure EOF is passed
        XCTAssertEqual(receivedInputData.last?.count, 0)

        let receivedString = String(bytes: receivedInputData.joined(separator: []), encoding: String.Encoding.utf8)
        XCTAssertEqual(receivedString, postBodyString)
    }

    func testAddressReuse() {
        var called: Bool = false
        let port = try! getUnusedTCPPort()
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ((Data) -> Void)) in
            startResponse("200 OK", [])
            sendBody(Data())
            self.loop.stop()
            called = true
        }
        let server1 = DefaultHTTPServer(eventLoop: loop, port: port, app: app)
        try! server1.start()
        server1.stop()

        let server2 = DefaultHTTPServer(eventLoop: loop, port: port, app: app)
        try! server2.start()

        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            let task = self.session.dataTask(
                with: URL(string: "http://[::1]:\(port)")!
            )
            task.resume()
        }

        loop.runForever()
        XCTAssert(called)
    }

    func testStopAndWait() {
        let port = try! getUnusedTCPPort()
        let server = DefaultHTTPServer(eventLoop: loop, port: port) {
            (
                environ: [String: Any],
                startResponse: ((String, [(String, String)]) -> Void),
                sendBody: ((Data) -> Void)
            ) in
            startResponse("200 OK", [])
            sendBody(Data())
        }
        try! server.start()

        queue.async {
            self.loop.runForever()
        }
        assertExecutingTime(0, accuracy: 0.5) {
            server.stopAndWait()
        }
        loop.stop()
    }
}
