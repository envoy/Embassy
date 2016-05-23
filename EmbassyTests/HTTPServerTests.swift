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

    func testHTTPServer() {
        let app = { (environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
            startResponse("200 OK", [])
            sendBody(Array(String(environ).utf8))
            sendBody([])
        }
        let loop = try! EventLoop(selector: try! KqueueSelector())
        let server = HTTPServer(eventLoop: loop, app: app, port: 8889)
        
        try! server.start()
        
        // TODO: do the test here
        
        loop.runForever()
    }

}
