//
//  TCPSocketTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Dispatch
import XCTest

@testable import Embassy

#if os(Linux)
    extension TCPSocketTests {
        static var allTests = [
            ("testAccept", testAccept),
            ("testReadAndWrite", testReadAndWrite),
            ("testGetPeerName", testGetPeerName),
            ("testGetSockName", testGetSockName),
        ]
    }
#endif

class TCPSocketTests: XCTestCase {
    let queue = DispatchQueue(label: "com.envoy.embassy-tests.tcp-sockets", attributes: [])

    func testAccept() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket(blocking: true)
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let exp0 = expectation(description: "socket accepcted")
        var acceptedSocket: TCPSocket!
        queue.async {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }

        let clientSocket = try! TCPSocket()
        try! clientSocket.connect(host: "::1", port: port)

        waitForExpectations(timeout: 3) { error in
            XCTAssertNil(error)
        }
        XCTAssertNotNil(acceptedSocket)
    }

    func testReadAndWrite() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket(blocking: true)
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let exp0 = expectation(description: "socket accepcted")
        var acceptedSocket: TCPSocket!
        queue.async {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }

        let clientSocket = try! TCPSocket(blocking: true)
        try! clientSocket.connect(host: "::1", port: port)

        waitForExpectations(timeout: 4) { error in
            XCTAssertNil(error)
        }

        let stringToSend = "hello baby"
        let bytesToSend = Data(stringToSend.utf8)

        var receivedData: Data?
        let exp1 = expectation(description: "socket received")

        let sentBytes = try! clientSocket.send(data: bytesToSend)
        XCTAssertEqual(sentBytes, bytesToSend.count)

        queue.async {
            receivedData = try! acceptedSocket.recv(size: 1024)
            exp1.fulfill()
        }

        waitForExpectations(timeout: 3) { error in
            XCTAssertNil(error)
        }

        XCTAssertEqual(String(bytes: receivedData!, encoding: String.Encoding.utf8), stringToSend)
    }

    func testGetPeerName() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket(blocking: true)
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let exp0 = expectation(description: "socket accepcted")
        var acceptedSocket: TCPSocket!
        queue.async {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }

        let clientSocket = try! TCPSocket(blocking: true)
        try! clientSocket.connect(host: "::1", port: port)

        waitForExpectations(timeout: 4, handler: nil)

        XCTAssertEqual(try! acceptedSocket.getPeerName().0, "::1")
        XCTAssertEqual(try! clientSocket.getPeerName().0, "::1")
    }

    func testGetSockName() {
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket(blocking: true)
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let exp0 = expectation(description: "socket accepcted")
        var acceptedSocket: TCPSocket!
        queue.async {
            acceptedSocket = try! listenSocket.accept()
            exp0.fulfill()
        }

        let clientSocket = try! TCPSocket(blocking: true)
        try! clientSocket.connect(host: "::1", port: port)

        waitForExpectations(timeout: 4, handler: nil)

        XCTAssertEqual(try! acceptedSocket.getSockName().0, "::1")
        XCTAssertEqual(try! clientSocket.getSockName().0, "::1")
    }
}
