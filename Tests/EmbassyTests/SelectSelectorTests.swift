//
//  SelectSelectorTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 1/13/17.
//  Copyright © 2017 Fang-Pen Lin. All rights reserved.
//

import Foundation
import XCTest
import Dispatch

@testable import Embassy

#if os(Linux)
    extension SelectSelectorTests {
        static var allTests = [
            ("testRegister", testRegister),
            ("testUnregister", testUnregister),
            ("testRegisterKeyError", testRegisterKeyError),
            ("testUnregisterKeyError", testUnregisterKeyError),
            ("testSelectOneSocket", testSelectOneSocket),
            ("testSelectEventFilter", testSelectEventFilter),
            ("testSelectAfterUnregister", testSelectAfterUnregister),
            ("testSelectMultipleSocket", testSelectMultipleSocket),
        ]
    }
#endif

class SelectSelectorTests: XCTestCase {
    let queue = DispatchQueue(label: "com.envoy.embassy-tests.select", attributes: [])

    func testRegister() {
        let selector = try! SelectSelector()
        let socket = try! TCPSocket()

        XCTAssertNil(selector[socket.fileDescriptor])

        let data = "my data"
        try! selector.register(socket.fileDescriptor, events: [.read], data: data)

        let key = selector[socket.fileDescriptor]
        XCTAssertEqual(key?.fileDescriptor, socket.fileDescriptor)
        XCTAssertEqual(key?.events, [.read])
        XCTAssertEqual(key?.data as? String, data)
    }

    func testUnregister() {
        let selector = try! SelectSelector()
        let socket = try! TCPSocket()

        try! selector.register(socket.fileDescriptor, events: [.read], data: nil)

        let key = try! selector.unregister(socket.fileDescriptor)
        XCTAssertNil(selector[socket.fileDescriptor])
        XCTAssertNil(key.data as? String)
        XCTAssertEqual(key.fileDescriptor, socket.fileDescriptor)
        XCTAssertEqual(key.events, [.read])
    }

    func testRegisterKeyError() {
        let selector = try! SelectSelector()
        let socket = try! TCPSocket()
        try! selector.register(socket.fileDescriptor, events: [.read], data: nil)

        XCTAssertThrowsError(try selector.register(
            socket.fileDescriptor,
            events: [.read],
            data: nil
        )) { error in
            guard let error = error as? SelectSelector.Error else {
                XCTFail()
                return
            }
            guard case .keyError = error else {
                XCTFail()
                return
            }
        }
    }

    func testUnregisterKeyError() {
        let selector = try! SelectSelector()
        let socket = try! TCPSocket()

        XCTAssertThrowsError(try selector.unregister(socket.fileDescriptor)) { error in
            guard let error = error as? SelectSelector.Error else {
                XCTFail()
                return
            }
            guard case .keyError = error else {
                XCTFail()
                return
            }
        }
    }

    func testSelectOneSocket() {
        let selector = try! SelectSelector()

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        try! selector.register(listenSocket.fileDescriptor, events: [.read], data: nil)

        // ensure we have a correct timeout here
        assertExecutingTime(2, accuracy: 1) {
            XCTAssertEqual(try! selector.select(timeout: 2.0).count, 0)
        }

        let clientSocket = try! TCPSocket()

        let emptyIOEvents = assertExecutingTime(1, accuracy: 1) {
            return try! selector.select(timeout: 1.0)
        }
        XCTAssertEqual(emptyIOEvents.count, 0)

        // make a connect 1 seconds later
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            try! clientSocket.connect(host: "::1", port: port)
        }

        let ioEvents = assertExecutingTime(1, accuracy: 1) {
            return try! selector.select(timeout: 10.0)
        }
        XCTAssertEqual(ioEvents.count, 1)
        XCTAssertEqual(ioEvents.first?.0.fileDescriptor, listenSocket.fileDescriptor)
        XCTAssertEqual(ioEvents.first?.0.events, [.read])
        XCTAssertNil(ioEvents.first?.0.data)
    }

    func testSelectEventFilter() {
        let selector = try! SelectSelector()

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        try! selector.register(listenSocket.fileDescriptor, events: [.write], data: nil)

        XCTAssertEqual(try! selector.select(timeout: 1.0).count, 0)

        let clientSocket = try! TCPSocket()
        // make a connect 1 seconds later
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            try! clientSocket.connect(host: "::1", port: port)
        }

        // ensure we don't get any event triggered in two seconds
        XCTAssertEqual(try! selector.select(timeout: 2.0).count, 0)
    }

    func testSelectAfterUnregister() {
        let selector = try! SelectSelector()

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        try! selector.register(listenSocket.fileDescriptor, events: [.read], data: nil)

        let clientSocket = try! TCPSocket()
        // make a connect 1 seconds later
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            try! clientSocket.connect(host: "::1", port: port)
        }

        assertExecutingTime(1, accuracy: 1) {
            let events = try! selector.select(timeout: 2.0)
            let result = toEventSet(events)
            XCTAssertEqual(result, Set([
                FileDescriptorEvent(fileDescriptor: listenSocket.fileDescriptor, ioEvent: .read),
            ]))
        }

        try! selector.unregister(listenSocket.fileDescriptor)

        let clientSocket2 = try! TCPSocket()
        // make a connect 1 seconds later
        queue.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        ) {
            try! clientSocket2.connect(host: "::1", port: port)
        }

        assertExecutingTime(2, accuracy: 1) {
            XCTAssertEqual(try! selector.select(timeout: 2.0).count, 0)
        }
    }

    func testSelectMultipleSocket() {
        let selector = try! SelectSelector()

        let port = try! getUnusedTCPPort()

        let clientSocket = try! TCPSocket()

        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()
        try! selector.register(listenSocket.fileDescriptor, events: [.read, .write], data: nil)

        try! clientSocket.connect(host: "::1", port: port)
        try! selector.register(clientSocket.fileDescriptor, events: [.read, .write], data: nil)

        sleep(1)

        let ioEvents0 = assertExecutingTime(0, accuracy: 1) {
            return try! selector.select(timeout: 10.0)
        }
        let result0 = toEventSet(ioEvents0)
        XCTAssertEqual(result0, Set([
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: listenSocket.fileDescriptor, ioEvent: .read),
        ]))

        let acceptedSocket = try! listenSocket.accept()
        try! selector.register(acceptedSocket.fileDescriptor, events: [.read, .write], data: nil)

        let ioEvents1 = assertExecutingTime(0, accuracy: 1) {
            return try! selector.select(timeout: 10.0)
        }
        let result1 = toEventSet(ioEvents1)
        XCTAssertEqual(result1, Set([
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .write),
        ]))

        // we should have no events now
        assertExecutingTime(1, accuracy: 1) {
            return try! selector.select(timeout: 1)
        }

        try! clientSocket.send(data: Data("hello".utf8))
        // wait a little while so that read event will surely be triggered
        sleep(1)

        let ioEvents2 = assertExecutingTime(0, accuracy: 1) {
            return try! selector.select(timeout: 10.0)
        }
        let result2 = toEventSet(ioEvents2)
        XCTAssertEqual(result2, Set([
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .read),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .write)
        ]))

        let receivedString = String(
            bytes: try! acceptedSocket.recv(size: 1024),
            encoding: String.Encoding.utf8
        )
        XCTAssertEqual(receivedString, "hello")

        let ioEvents3 = assertExecutingTime(0, accuracy: 1) {
            return try! selector.select(timeout: 10.0)
        }
        let result3 = toEventSet(ioEvents3)
        XCTAssertEqual(result3, Set([
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .write)
        ]))

        // we should have no events now
        assertExecutingTime(1, accuracy: 1) {
            return try! selector.select(timeout: 1)
        }
    }

    fileprivate func toEventSet(_ events: [(SelectorKey, Set<IOEvent>)]) -> Set<FileDescriptorEvent> {
        return Set(events.flatMap { (key, ioEvents) in
            return ioEvents.map { FileDescriptorEvent(fileDescriptor: key.fileDescriptor, ioEvent: $0) }
        })
    }
}
