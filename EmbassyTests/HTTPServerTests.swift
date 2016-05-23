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

}
