//
//  TCPSocketTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class TCPSocketTests: XCTestCase {
    func testAccept() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        let exp0 = expectationWithDescription("socket accepcted")
        var acceptedSocket: TCPSocket!
        let acceptQueue = dispatch_queue_create("com.envoy.embassy-tcpsocket-tests", DISPATCH_QUEUE_SERIAL)
        dispatch_async(acceptQueue) {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }
        
        let clientSocket = try! TCPSocket()
        try! clientSocket.connect("127.0.0.1", port: port)
        
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertNil(error)
        }
        XCTAssertNotNil(acceptedSocket)
    }
}
