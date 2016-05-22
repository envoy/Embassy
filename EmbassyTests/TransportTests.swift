//
//  TransportTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class TransportTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.event-loop", DISPATCH_QUEUE_SERIAL)
    func testReadAndWrite() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []
        
        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
            if clientReceivedData.count >= 3 {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!
        
        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
            }
        }
        
        try! clientSocket.connect("::1", port: port)
        
        loop.callLater(1) {
            clientTransport.writeUTF8("a")
        }
        loop.callLater(2) {
            serverTransport.writeUTF8("1")
        }
        loop.callLater(3) {
            clientTransport.writeUTF8("b")
        }
        loop.callLater(4) {
            serverTransport.writeUTF8("2")
        }
        loop.callLater(5) {
            clientTransport.writeUTF8("c")
        }
        loop.callLater(6) {
            serverTransport.writeUTF8("3")
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * NSEC_PER_SEC)), queue) {
            loop.stop()
        }
        
        loop.runForever()
        
        XCTAssertEqual(serverReceivedData, ["a", "b", "c"])
        XCTAssertEqual(clientReceivedData, ["1", "2", "3"])
    }

}
