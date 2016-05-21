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
        
        let data = "my data"
        try! selector.register(socket.fileDescriptor, events: Set<IOEvent>([.Read]), data: data)
        
        try! selector.unregister(socket.fileDescriptor)
        XCTAssertNil(selector[socket.fileDescriptor])
    }
}
