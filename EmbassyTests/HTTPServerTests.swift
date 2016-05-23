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

    func testEnviron() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        var receivedEnviron: [String: AnyObject]!
        let app = { (environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            receivedEnviron = environ
            loop.stop()
        }
        let server = HTTPServer(eventLoop: loop, app: app, port: port)
        
        try! server.start()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let task = NSURLSession.sharedSession().dataTaskWithURL( NSURL(string: "http://[::1]:\(port)/path?foo=bar")!)
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
    }
    
    func testStartResponse() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let app = { (environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
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
                loop.stop()
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

}
