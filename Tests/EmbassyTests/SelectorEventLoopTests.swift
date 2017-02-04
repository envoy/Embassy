//
//  SelectorEventLoopTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import XCTest
import Dispatch

@testable import Embassy

#if os(Linux)
    extension SelectorEventLoopTests {
        static var allTests = [
            ("testStop", testStop),
            ("testCallSoon", testCallSoon),
            ("testCallLater", testCallLater),
            ("testCallAtOrder", testCallAtOrder),
            ("testSetReader", testSetReader),
            ("testSetWriter", testSetWriter),
            ("testRemoveReader", testRemoveReader),
        ]
    }
#endif

class SelectorEventLoopTests: XCTestCase {
    let queue = DispatchQueue(label: "com.envoy.embassy-tests.event-loop", attributes: [])
    var loop: SelectorEventLoop!

    override func setUp() {
        super.setUp()
        loop = try! SelectorEventLoop(selector: try! TestingSelector())

        // set a 30 seconds timeout
        queue.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(30 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        ) {
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
        queue.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        ) {
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
        loop.call {
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
        loop.call(withDelay: 0) {
            events.append(0)
        }
        loop.call(withDelay: 1) {
            events.append(1)
        }
        loop.call(withDelay: 2) {
            self.loop.stop()
        }
        loop.call(withDelay: 3) {
            events.append(3)
        }
        assertExecutingTime(2, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertEqual(events, [0, 1])
    }

    func testCallAtOrder() {
        var events: [Int] = []
        let now = Date()
        loop.call(atTime: now.addingTimeInterval(0)) {
            events.append(0)
        }
        loop.call(atTime: now.addingTimeInterval(0.000002)) {
            events.append(2)
        }
        loop.call(atTime: now.addingTimeInterval(0.000001)) {
            events.append(1)
        }
        loop.call(atTime: now.addingTimeInterval(0.000004)) {
            events.append(4)
            self.loop.stop()
        }
        loop.call(atTime: now.addingTimeInterval(0.000003)) {
            events.append(3)
        }
        assertExecutingTime(0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertEqual(events, [0, 1, 2, 3, 4])
    }

    func testSetReader() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()
        var readerCalled = false

        loop.setReader(listenSocket.fileDescriptor) {
            readerCalled = true
            self.loop.stop()
        }

        let clientSocket = try! TCPSocket()

        // make a connection 1 seconds later
        loop.call(withDelay: 1) {
            try! clientSocket.connect(host: "::1", port: port)
        }

        assertExecutingTime(1.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssert(readerCalled)
    }

    func testSetWriter() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()
        var writerCalled = false

        let clientSocket = try! TCPSocket()

        // make a connect 1 seconds later
        loop.call(withDelay: 1) { [unowned self] in
            try! clientSocket.connect(host: "::1", port: port)

            // Notice: It seems we should only select on the socket after it's either connecting
            // or listening, and that's why we put setWriter here instead of before or after
            // ref: http://stackoverflow.com/q/41656400/25077
            self.loop.setWriter(clientSocket.fileDescriptor) {
                writerCalled = true
                self.loop.stop()
            }
        }

        assertExecutingTime(1.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssert(writerCalled)
    }

    func testRemoveReader() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let clientSocket = try! TCPSocket()
        var acceptedSocket: TCPSocket!

        var readData = [String]()
        let readAcceptedSocket = {
            let data = try! acceptedSocket.recv(size: 1024)
            readData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
            if readData.count >= 2 {
                self.loop.removeReader(acceptedSocket.fileDescriptor)
            }
        }

        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            self.loop.setReader(acceptedSocket.fileDescriptor, callback: readAcceptedSocket)
        }

        try! clientSocket.connect(host: "::1", port: port)

        loop.call(withDelay: 1) {
            try! clientSocket.send(data: Data("hello".utf8))
        }
        loop.call(withDelay: 2) {
            try! clientSocket.send(data: Data("baby".utf8))
        }
        loop.call(withDelay: 3) {
            try! clientSocket.send(data: Data("fin".utf8))
        }
        loop.call(withDelay: 4) {
            self.loop.stop()
        }

        assertExecutingTime(4.0, accuracy: 0.5) {
            self.loop.runForever()
        }
        XCTAssertEqual(readData, ["hello", "baby"])
    }
}
