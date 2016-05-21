//
//  KqueueSelectorTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class KqueueSelectorTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.kqueue", DISPATCH_QUEUE_SERIAL)
    
    func testRegister() {
        let selector = try! KqueueSelector()
        let socket = try! TCPSocket()
        
        XCTAssertNil(selector[socket.fileDescriptor])
        
        let data = "my data"
        try! selector.register(socket.fileDescriptor, events: Set<IOEvent>([.Read]), data: data)
        
        let key = selector[socket.fileDescriptor]
        XCTAssertEqual(key?.fileDescriptor, socket.fileDescriptor)
        XCTAssertEqual(key?.events, Set<IOEvent>([.Read]))
        XCTAssertEqual(key?.data as? String, data)
    }

    func testUnregister() {
        let selector = try! KqueueSelector()
        let socket = try! TCPSocket()
        
        try! selector.register(socket.fileDescriptor, events: Set<IOEvent>([.Read]), data: nil)
        
        try! selector.unregister(socket.fileDescriptor)
        XCTAssertNil(selector[socket.fileDescriptor])
    }
    
    func testSelectOneSocket() {
        let selector = try! KqueueSelector()
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        listenSocket.blocking = false
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        try! selector.register(listenSocket.fileDescriptor, events: Set<IOEvent>([.Read]), data: nil)
        
        // ensure we have a correct timeout here
        let begin0 = NSDate()
        XCTAssertEqual(try! selector.select(2.0).count, 0)
        let elapsed0 = NSDate().timeIntervalSinceDate(begin0)
        XCTAssertEqualWithAccuracy(elapsed0, 2, accuracy: 1)
        
        let clientSocket = try! TCPSocket()
        
        // make a connect 1 seconds later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            try! clientSocket.connect("::1", port: port)
        }
        
        let begin1 = NSDate()
        let ioEvents = try! selector.select(10.0)
        let elapsed1 = NSDate().timeIntervalSinceDate(begin1)
        XCTAssertEqual(ioEvents.first?.0.fileDescriptor, listenSocket.fileDescriptor)
        XCTAssertNil(ioEvents.first?.0.data)
        XCTAssertEqual(ioEvents.first?.0.events, Set<IOEvent>([.Read]))
        XCTAssertEqualWithAccuracy(elapsed1, 1, accuracy: 1)
    }
    
    func testSelectEventFilter() {
        let selector = try! KqueueSelector()
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        listenSocket.blocking = false
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        try! selector.register(listenSocket.fileDescriptor, events: Set<IOEvent>([.Write]), data: nil)
        
        XCTAssertEqual(try! selector.select(1.0).count, 0)
        
        let clientSocket = try! TCPSocket()
        // make a connect 1 seconds later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            try! clientSocket.connect("::1", port: port)
        }
        
        // ensure we don't get any event triggered
        XCTAssertEqual(try! selector.select(2.0).count, 0)
    }
}
