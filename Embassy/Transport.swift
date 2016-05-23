//
//  Transport.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

class Transport {
    enum CloseReason {
        /// Connection closed by peer
        case ByPeer
        /// Connection closed by ourselve
        case ByLocal
        
        var isByPeer: Bool {
            if case .ByPeer = self {
                return true
            }
            return false
        }
        
        var isByLocal: Bool {
            if case .ByLocal = self {
                return true
            }
            return false
        }
    }
    
    /// Size for recv
    static let recvChunkSize = 1024
    
    /// Is this transport closed or not
    private(set) var closed: Bool = false
    /// Is this transport closing
    private(set) var closing: Bool = false
    var closedCallback: (CloseReason -> Void)?
    var readDataCallback: ([UInt8] -> Void)?
    
    private let socket: TCPSocket
    private let eventLoop: EventLoop
    // buffer for sending data out
    private var outgoingBuffer = [UInt8]()
    
    init(socket: TCPSocket, eventLoop: EventLoop, closedCallback: (CloseReason -> Void)? = nil, readDataCallback: ([UInt8] -> Void)? = nil) {
        socket.ignoreSigPipe = true
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
        // ensure we are not closed nor closing
        guard !closed && !closing else {
            // TODO: or raise error?
            return
        }
        // TODO: more efficient way to handle the outgoing buffer?
        outgoingBuffer += data
        handleWrite()
    }
    
    /// Send string with UTF8 encoding to peer
    ///  - Parameter string: string to send as UTF8
    func writeUTF8(string: String) {
        write(Array(string.utf8))
    }
    
    /// Flush outgoing data and close the transport
    func close() {
        // ensure we are not closed nor closing
        guard !closed && !closing else {
            // TODO: or raise error?
            return
        }
        closing = true
        handleWrite()
    }
    
    private func handleRead() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        let data = try! socket.recv(Transport.recvChunkSize)
        guard data.count > 0 else {
            closed = true
            eventLoop.removeReader(socket.fileDescriptor)
            eventLoop.removeWriter(socket.fileDescriptor)
            if let callback = closedCallback {
                callback(.ByPeer)
            }
            socket.close()
            return
        }
        // ensure we are not closing
        guard !closing else {
            return
        }
        if let callback = readDataCallback {
            callback(data)
        }
    }
    
    private func handleWrite() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        // ensure we have something to write
        guard outgoingBuffer.count > 0 else {
            if closing {
                closed = true
                eventLoop.removeReader(socket.fileDescriptor)
                eventLoop.removeWriter(socket.fileDescriptor)
                if let callback = closedCallback {
                    callback(.ByLocal)
                }
                socket.close()
            }
            return
        }
        let sentBytes = try! socket.send(outgoingBuffer)
        outgoingBuffer = Array(outgoingBuffer[sentBytes..<outgoingBuffer.count])
    }
}
