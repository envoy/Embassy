//
//  TransportTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Dispatch
import XCTest

@testable import Embassy

#if os(Linux)
    extension TransportTests {
        static var allTests = [
            ("testBigChunkReadAndWrite", testBigChunkReadAndWrite),
            ("testReadAndWrite", testReadAndWrite),
            ("testCloseByPeer", testCloseByPeer),
            ("testReadingPause", testReadingPause),
        ]
    }
#endif


class TransportTests: XCTestCase {
    let queue = DispatchQueue(label: "com.envoy.embassy-tests.event-loop", attributes: [])
    func testBigChunkReadAndWrite() {
        let loop = try! SelectorEventLoop(selector: try! TestingSelector())

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []
        var totalReceivedSize = 0
        let dataChunk1 = makeRandomString(128)
        let dataChunk2 = makeRandomString(5743)
        let dataChunk3 = makeRandomString(2731)
        let dataChunk4 = makeRandomString(538)
        let dataChunk5 = makeRandomString(2048)
        let dataChunk6 = makeRandomString(1)
        let totalDataSize = [
            dataChunk1,
            dataChunk2,
            dataChunk3,
            dataChunk4,
            dataChunk5,
            dataChunk6
        ].reduce(0) { $0 + $1.characters.count }

        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
            totalReceivedSize += clientReceivedData.last!.characters.count
            if totalReceivedSize >= totalDataSize {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!

        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
                totalReceivedSize += serverReceivedData.last!.characters.count
                if totalReceivedSize >= totalDataSize {
                    loop.stop()
                }
            }
        }

        try! clientSocket.connect(host: "::1", port: port)


        loop.call(withDelay: 1) {
            clientTransport.write(string: dataChunk1)
        }
        loop.call(withDelay: 2) {
            serverTransport.write(string: dataChunk2)
        }
        loop.call(withDelay: 3) {
            clientTransport.write(string: dataChunk3)
        }
        loop.call(withDelay: 4) {
            serverTransport.write(string: dataChunk4)
        }
        loop.call(withDelay: 5) {
            clientTransport.write(string: dataChunk5)
        }
        loop.call(withDelay: 6) {
            serverTransport.write(string: dataChunk6)
        }

        loop.call(withDelay: 10) {
            loop.stop()
        }

        loop.runForever()

        XCTAssertEqual(serverReceivedData.joined(separator: ""), [
            dataChunk1,
            dataChunk3,
            dataChunk5
        ].joined(separator: ""))
        XCTAssertEqual(clientReceivedData.joined(separator: ""), [
            dataChunk2,
            dataChunk4,
            dataChunk6
        ].joined(separator: ""))
    }

    func testReadAndWrite() {
        let loop = try! SelectorEventLoop(selector: try! TestingSelector())

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []

        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
            if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!

        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
                if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                    loop.stop()
                }
            }
        }

        try! clientSocket.connect(host: "::1", port: port)

        loop.call(withDelay: 1) {
            clientTransport.write(string: "a")
        }
        loop.call(withDelay: 2) {
            serverTransport.write(string: "1")
        }
        loop.call(withDelay: 3) {
            clientTransport.write(string: "b")
        }
        loop.call(withDelay: 4) {
            serverTransport.write(string: "2")
        }
        loop.call(withDelay: 5) {
            clientTransport.write(string: "c")
        }
        loop.call(withDelay: 6) {
            serverTransport.write(string: "3")
        }

        loop.call(withDelay: 10) {
            loop.stop()
        }

        loop.runForever()

        XCTAssertEqual(serverReceivedData, ["a", "b", "c"])
        XCTAssertEqual(clientReceivedData, ["1", "2", "3"])
    }

    func testCloseByPeer() {
        let loop = try! SelectorEventLoop(selector: try! TestingSelector())

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { _ in

        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!
        var serverReceivedData: [String] = []
        var serverTransportClosed: Bool = false

        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(
                socket: acceptedSocket,
                eventLoop: loop,
                closedCallback: { reason in
                    XCTAssert(serverTransport.closed)
                    XCTAssert(reason.isByPeer)
                    serverTransportClosed = true
                    loop.stop()
                },
                readDataCallback: { data in
                    serverReceivedData.append(String(bytes: data, encoding: .utf8)!)
                }
            )
        }

        try! clientSocket.connect(host: "::1", port: port)
        let bigDataChunk = makeRandomString(574300)

        loop.call(withDelay: 1) {
            clientTransport.write(string: "hello")
        }

        loop.call(withDelay: 2) {
            XCTAssertFalse(clientTransport.closed)
            XCTAssertFalse(clientTransport.closing)
            clientTransport.write(string: bigDataChunk)
            clientTransport.close()
            XCTAssertTrue(clientTransport.closing)
        }

        loop.call(withDelay: 10) {
            loop.stop()
        }

        loop.runForever()

        XCTAssert(serverTransportClosed)
        XCTAssert(clientTransport.closed)
        XCTAssert(serverTransport.closed)
        XCTAssertEqual(
            serverReceivedData.joined(separator: "").characters.count,
            "hello".characters.count + bigDataChunk.characters.count
        )
    }

    func testReadingPause() {
        let loop = try! SelectorEventLoop(selector: try! TestingSelector())

        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port: port)
        try! listenSocket.listen()

        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []

        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
            if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!

        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: String.Encoding.utf8)!)
                if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                    loop.stop()
                }
            }
        }

        try! clientSocket.connect(host: "::1", port: port)

        loop.call(withDelay: 1) {
            clientTransport.write(string: "a")
        }
        loop.call(withDelay: 2) {
            serverTransport.write(string: "1")
        }
        loop.call(withDelay: 3) {
            clientTransport.resume(reading: false)
            serverTransport.resume(reading: false)
            clientTransport.write(string: "b")
        }
        loop.call(withDelay: 4) {
            XCTAssertEqual(clientReceivedData.count, 1)
            XCTAssertEqual(serverReceivedData.count, 1)
            serverTransport.write(string: "2")
        }
        loop.call(withDelay: 5) {
            XCTAssertEqual(clientReceivedData.count, 1)
            XCTAssertEqual(serverReceivedData.count, 1)
            clientTransport.write(string: "c")
        }
        loop.call(withDelay: 6) {
            XCTAssertEqual(clientReceivedData.count, 1)
            XCTAssertEqual(serverReceivedData.count, 1)
            serverTransport.write(string: "3")
        }
        loop.call(withDelay: 7) {
            clientTransport.resume(reading: true)
            serverTransport.resume(reading: true)
        }
        loop.call(withDelay: 10) {
            loop.stop()
        }

        loop.runForever()

        XCTAssertEqual(serverReceivedData, ["a", "bc"])
        XCTAssertEqual(clientReceivedData, ["1", "23"])
    }
}
