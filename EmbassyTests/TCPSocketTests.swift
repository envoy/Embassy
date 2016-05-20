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
    let queue = dispatch_queue_create("com.envoy.embassy-tcpsocket-tests", DISPATCH_QUEUE_SERIAL)
    
    func testAccept() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        let exp0 = expectationWithDescription("socket accepcted")
        var acceptedSocket: TCPSocket!
        dispatch_async(queue) {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }
        
        let clientSocket = try! TCPSocket()
        try! clientSocket.connect("::1", port: port)
        
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertNil(error)
        }
        XCTAssertNotNil(acceptedSocket)
    }
    
    func testReadAndWrite() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        let exp0 = expectationWithDescription("socket accepcted")
        var acceptedSocket: TCPSocket!
        dispatch_async(queue) {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }
        
        let clientSocket = try! TCPSocket()
        try! clientSocket.connect("::1", port: port)
        
        waitForExpectationsWithTimeout(4) { error in
            XCTAssertNil(error)
        }
        
        let stringToSend = "hello baby"
        let bytesToSend = Array(stringToSend.utf8)
        
        var receivedData: [UInt8]?
        let exp1 = expectationWithDescription("socket received")
        
        let sentBytes = try! clientSocket.send(bytesToSend)
        XCTAssertEqual(sentBytes, bytesToSend.count)
        
        dispatch_async(queue) {
            receivedData = try! acceptedSocket.recv(1024)
            exp1.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertNil(error)
        }
        
        XCTAssertEqual(String(bytes: receivedData!, encoding: NSUTF8StringEncoding), stringToSend)
    }
}
