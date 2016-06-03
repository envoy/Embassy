//
//  HTTPServerTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class HTTPServerTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.http-server", DISPATCH_QUEUE_SERIAL)
    var loop: SelectorEventLoop!

    override func setUp() {
        super.setUp()
        loop = try! SelectorEventLoop(selector: try! KqueueSelector())

        // set a 30 seconds timeout
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * NSEC_PER_SEC)), queue) {
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
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            receivedEnviron = environ
            self.loop.stop()
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL(
                NSURL(string: "http://[::1]:\(port)/path?foo=bar")!
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
        XCTAssertNotNil(receivedEnviron["embassy.event_loop"] as? EventLoopType)
    }

    func testStartResponse() {
        let port = try! getUnusedTCPPort()
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("451 Big brother doesn't like this", [
                ("Content-Type", "video/porn"),
                ("Server", "Embassy-by-envoy"),
                ("X-Foo", "Bar"),
            ])
            sendBody([])
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        var receivedData: NSData?
        var receivedResponse: NSHTTPURLResponse?
        var receivedError: NSError?
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: "http://[::1]:\(port)")!) { (data, response, error) in
                receivedData = data
                receivedResponse = response as? NSHTTPURLResponse
                receivedError = error
                self.loop.stop()
            }
            task.resume()
        }

        loop.runForever()

        XCTAssertEqual(receivedData?.length, 0)
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 451)
        XCTAssertEqual(receivedResponse?.allHeaderFields["Content-Type"] as? String, "video/porn")
        XCTAssertEqual(receivedResponse?.allHeaderFields["Server"] as? String, "Embassy-by-envoy")
        XCTAssertEqual(receivedResponse?.allHeaderFields["X-Foo"] as? String, "Bar")
    }

    func testSendBody() {
        let port = try! getUnusedTCPPort()
        let bigDataChunk = Array(makeRandomString(574300).utf8)
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])
            sendBody(bigDataChunk)
            sendBody([])
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        var receivedData: NSData?
        var receivedResponse: NSHTTPURLResponse?
        var receivedError: NSError?
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: "http://[::1]:\(port)")!) { (data, response, error) in
                receivedData = data
                receivedResponse = response as? NSHTTPURLResponse
                receivedError = error
                self.loop.stop()
            }
            task.resume()
        }

        loop.runForever()

        let data = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(receivedData!.bytes), count: receivedData!.length))
        XCTAssertEqual(receivedData?.length, bigDataChunk.count)
        XCTAssertEqual(data, bigDataChunk)
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 200)
    }

    func testAsyncSendBody() {
        let port = try! getUnusedTCPPort()
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])

            let loop = environ["embassy.event_loop"] as! EventLoopType

            loop.callLater(1) {
                sendBody(Array("hello ".utf8))
            }
            loop.callLater(2) {
                sendBody(Array("baby ".utf8))
            }
            loop.callLater(3) {
                sendBody(Array("fin".utf8))
                sendBody([])
            }
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        var receivedData: NSData?
        var receivedResponse: NSHTTPURLResponse?
        var receivedError: NSError?
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: "http://[::1]:\(port)")!) { (data, response, error) in
                receivedData = data
                receivedResponse = response as? NSHTTPURLResponse
                receivedError = error
                self.loop.stop()
            }
            task.resume()
        }

        loop.runForever()

        XCTAssertEqual(NSString(data: receivedData!, encoding: NSUTF8StringEncoding)!, "hello baby fin")
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 200)
    }

    func testPostBody() {
        let port = try! getUnusedTCPPort()

        let postBodyString = makeRandomString(40960)
        var receivedInputData: [[UInt8]] = []
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                receivedInputData.append(data)
                sendBody(data)
            }
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let request = NSMutableURLRequest(URL: NSURL(string: "http://[::1]:\(port)")!)
            request.HTTPMethod = "POST"
            request.HTTPBody = postBodyString.dataUsingEncoding(NSUTF8StringEncoding)
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
                self.loop.stop()
            }
            task.resume()
        }

        loop.runForever()

        // ensure EOF is passed
        XCTAssertEqual(receivedInputData.last?.count, 0)

        let receivedString = String(bytes: receivedInputData.joinWithSeparator([]), encoding: NSUTF8StringEncoding)
        XCTAssertEqual(receivedString, postBodyString)
    }

    func testPostWithInitialBody() {
        let port = try! getUnusedTCPPort()

        // this chunk is small enough, ideally should be sent along with header (initial body)
        let postBodyString = "hello"
        var receivedInputData: [[UInt8]] = []
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                receivedInputData.append(data)
                sendBody(data)
            }
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)

        try! server.start()

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let request = NSMutableURLRequest(URL: NSURL(string: "http://[::1]:\(port)")!)
            request.HTTPMethod = "POST"
            request.HTTPBody = postBodyString.dataUsingEncoding(NSUTF8StringEncoding)
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
                self.loop.stop()
            }
            task.resume()
        }

        loop.runForever()

        // ensure EOF is passed
        XCTAssertEqual(receivedInputData.last?.count, 0)

        let receivedString = String(bytes: receivedInputData.joinWithSeparator([]), encoding: NSUTF8StringEncoding)
        XCTAssertEqual(receivedString, postBodyString)
    }

    func testAddressReuse() {
        var called: Bool = false
        let port = try! getUnusedTCPPort()
        let app = { (environ: [String: Any], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])
            sendBody([])
            self.loop.stop()
            called = true
        }
        let server1 = HTTPServer(eventLoop: loop, app: app, port: port)
        try! server1.start()
        server1.stop()

        let server2 = HTTPServer(eventLoop: loop, app: app, port: port)
        try! server2.start()

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL( NSURL(string: "http://[::1]:\(port)")!)
            task.resume()
        }

        loop.runForever()
        XCTAssert(called)
    }

}
