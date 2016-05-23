//
//  SelectorEventLoopTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class SelectorEventLoopTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.event-loop", DISPATCH_QUEUE_SERIAL)
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
    
    func testStop() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            XCTAssert(self.loop.running)
            self.loop.stop()
            XCTAssertFalse(self.loop.running)
        }
        
        XCTAssertFalse(loop.running)
        assertExecutingTime(1.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertFalse(loop.running)
    }
    
    func testCallSoon() {
        var called = false
        loop.callSoon {
            called = true
            self.loop.stop()
        }
        assertExecutingTime(0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssert(called)
    }
    
    func testCallLater() {
        var events: [Int] = []
        loop.callLater(0) {
            events.append(0)
        }
        loop.callLater(1) {
            events.append(1)
        }
        loop.callLater(2) {
            self.loop.stop()
        }
        loop.callLater(3) {
            events.append(3)
        }
        assertExecutingTime(2, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertEqual(events, [0, 1])
    }
    
    func testSetReader() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        var readerCalled = false
        
        loop.setReader(listenSocket.fileDescriptor) {
            readerCalled = true
            self.loop.stop()
        }
        
        let clientSocket = try! TCPSocket()
        
        // make a connect 1 seconds later
        loop.callLater(1) {
            try! clientSocket.connect("::1", port: port)
        }
        
        assertExecutingTime(1.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssert(readerCalled)
    }
    
    func testSetWriter() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        var writerCalled = false
        
        let clientSocket = try! TCPSocket()
        
        loop.setWriter(clientSocket.fileDescriptor) {
            writerCalled = true
            self.loop.stop()
        }
        
        // make a connect 1 seconds later
        loop.callLater(1) {
            try! clientSocket.connect("::1", port: port)
        }
        
        assertExecutingTime(1.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssert(writerCalled)
    }
    
    func testRemoveReader() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        let clientSocket = try! TCPSocket()
        var acceptedSocket: TCPSocket!
        
        var readData = [String]()
        let readAcceptedSocket = {
            let data = try! acceptedSocket.recv(1024)
            readData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
            if readData.count >= 2 {
                self.loop.removeReader(acceptedSocket.fileDescriptor)
            }
        }
        
        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            self.loop.setReader(acceptedSocket.fileDescriptor, callback: readAcceptedSocket)
        }
        
        try! clientSocket.connect("::1", port: port)

        loop.callLater(1) {
            try! clientSocket.send(Array("hello".utf8))
        }
        loop.callLater(2) {
            try! clientSocket.send(Array("baby".utf8))
        }
        loop.callLater(3) {
            try! clientSocket.send(Array("fin".utf8))
        }
        loop.callLater(4) {
            self.loop.stop()
        }
        
        assertExecutingTime(4.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertEqual(readData, ["hello", "baby"])
    }
}
