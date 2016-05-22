//
//  Transport.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

class Transport {
    /// Size for recv
    static let recvChunkSize = 1024
    
    /// Is this transport closed or not
    var closed: Bool = false
    private let socket: TCPSocket
    private let eventLoop: EventLoop
    // buffer for sending data out
    private var outgoingBuffer = [UInt8]()
    private let closedCallback: (Void -> Void)?
    private let readDataCallback: ([UInt8] -> Void)
    
    init(socket: TCPSocket, eventLoop: EventLoop, closedCallback: (Void -> Void)? = nil, readDataCallback: ([UInt8] -> Void)) {
        self.socket = socket
        self.eventLoop = eventLoop
        self.closedCallback = closedCallback
        self.readDataCallback = readDataCallback
        eventLoop.setReader(socket.fileDescriptor, callback: handleRead)
        eventLoop.setWriter(socket.fileDescriptor, callback: handleWrite)
    }
    
    deinit {
        eventLoop.removeReader(socket.fileDescriptor)
        eventLoop.removeWriter(socket.fileDescriptor)
    }
    
    /// Send data to peer (append in buffer and will be sent out later)
    ///  - Parameter data: data to send
    func write(data: [UInt8]) {
        // TODO: more efficient way to handle the outgoing buffer?
        outgoingBuffer += data
        handleWrite()
    }
    
    /// Send string with UTF8 encoding to peer
    ///  - Parameter string: string to send as UTF8
    func writeUTF8(string: String) {
        write(Array(string.utf8))
    }
    
    private func handleRead() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        let data = try! socket.recv(Transport.recvChunkSize)
        if data.count == 0 {
            if let callback = closedCallback {
                closed = true
                eventLoop.removeReader(socket.fileDescriptor)
                eventLoop.removeWriter(socket.fileDescriptor)
                callback()
            }
        }
        readDataCallback(data)
    }
    
    private func handleWrite() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        // ensure we have something to write
        guard outgoingBuffer.count > 0 else {
            return
        }
        let sentBytes = try! socket.send(outgoingBuffer)
        outgoingBuffer = Array(outgoingBuffer[sentBytes..<outgoingBuffer.count])
    }
}
