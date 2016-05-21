//
//  EventLoopTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class EventLoopTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.event-loop", DISPATCH_QUEUE_SERIAL)
    func testStop() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            XCTAssert(loop.running)
            loop.stop()
            XCTAssertFalse(loop.running)
        }
        
        XCTAssertFalse(loop.running)
        assertExecutingTime(1.0, accuracy: 0.5) {
            loop.runForever()
        }
        XCTAssertFalse(loop.running)
    }
    
    func testSetReader() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        loop.setReader(listenSocket.fileDescriptor) {
            loop.stop()
        }
        
        // make a connect 1 seconds later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            let clientSocket = try! TCPSocket()
            try! clientSocket.connect("::1", port: port)
        }
        
        assertExecutingTime(1.0, accuracy: 0.5) {
            loop.runForever()
        }
    }
    
    func testSetWriter() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        let clientSocket = try! TCPSocket()
        
        loop.setWriter(clientSocket.fileDescriptor) {
            loop.stop()
        }
        
        // make a connect 1 seconds later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            try! clientSocket.connect("::1", port: port)
        }
        
        assertExecutingTime(1.0, accuracy: 0.5) {
            loop.runForever()
        }
    }
    
    func testRemoveReader() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
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
                loop.removeReader(acceptedSocket.fileDescriptor)
            }
        }
        
        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            loop.setReader(acceptedSocket.fileDescriptor, callback: readAcceptedSocket)
        }
        
        try! clientSocket.connect("::1", port: port)

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            try! clientSocket.send(Array("hello".utf8))
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * NSEC_PER_SEC)), queue) {
            try! clientSocket.send(Array("baby".utf8))
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3 * NSEC_PER_SEC)), queue) {
            try! clientSocket.send(Array("fin".utf8))
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4 * NSEC_PER_SEC)), queue) {
            loop.stop()
        }
        
        assertExecutingTime(4.0, accuracy: 0.5) {
            loop.runForever()
        }
        XCTAssertEqual(readData, ["hello", "baby"])
    }
}
