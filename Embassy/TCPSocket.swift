//
//  TCPSocket.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Class wrapping around TCP/IPv6 socket
public final class TCPSocket {
    public enum Error: ErrorType {
        case SocketError(number: Int, message: String)
        /// Return a socket error with the last error number and description
        static func lastSocketError() -> Error {
            return .SocketError(number: Int(errno), message: lastErrorDescription())
        }
        /// Return description for last error
        static func lastErrorDescription() -> String {
            return String.fromCString(UnsafePointer(strerror(errno))) ?? "Unknown Error: \(errno)"
        }
    }
    
    /// The file descriptor number for socket
    let fileDescriptor: Int32
    
    /// Whether is this socket in block mode or not
    var blocking: Bool {
        get {
            let flags = fcntl(fileDescriptor, F_GETFL, 0)
            return flags & O_NONBLOCK == 0
        }
        
        set {
            let flags = fcntl(fileDescriptor, F_GETFL, 0)
            let newFlags: Int32
            if newValue {
                newFlags = flags & ~O_NONBLOCK
            } else {
                newFlags = flags | O_NONBLOCK
            }
            let _ = fcntl(fileDescriptor, F_SETFL, newFlags)
        }
    }
    
    init() throws {
        fileDescriptor = socket(AF_INET6, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw Error.lastSocketError()
        }
    }
    
    init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }
    
    /// Bind the socket at given port and interface
    ///  - Parameter port: port number to bind to
    ///  - Parameter interface: networking interface to bind to, in IPv6 format
    ///  - Parameter addressReusable: should we make address reusable
    func bind(port: Int, interface: String = "::", addressReusable: Bool = true) throws {
        // create IPv6 socket address
        var address = sockaddr_in6(
            sin6_len: UInt8(strideof(sockaddr_in6)),
            sin6_family: UInt8(AF_INET6),
            sin6_port: UInt16(port).bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: try ipAddressToBinary(interface),
            sin6_scope_id: 0
        )
        // bind the address and port on socket
        guard withUnsafePointer(&address, { pointer in
            return Darwin.bind(fileDescriptor, UnsafePointer<sockaddr>(pointer), socklen_t(sizeof(sockaddr_in6))) >= 0
        }) else {
            throw Error.lastSocketError()
        }
        
        // make address reusable
        if addressReusable {
            var reuse = Int32(1)
            guard setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(sizeof(Int32))) >= 0 else {
                throw Error.lastSocketError()
            }
        }
    }
    
    /// Listen incomming connections
    ///  - Parameter backlog: maximum backlog of incoming connections
    func listen(backlog: Int = Int(SOMAXCONN)) throws {
        guard Darwin.listen(fileDescriptor, Int32(backlog)) != -1 else {
            throw Error.lastSocketError()
        }
    }
    
    /// Accept a new connection
    func accept() throws -> TCPSocket {
        var address = sockaddr_in6()
        var size = socklen_t(sizeof(sockaddr_in6))
        let clientFileDescriptor = withUnsafeMutablePointer(&address) { pointer in
            return Darwin.accept(fileDescriptor, UnsafeMutablePointer<sockaddr>(pointer), &size)
        }
        guard clientFileDescriptor >= 0 else {
            throw Error.lastSocketError()
        }
        return TCPSocket(fileDescriptor: clientFileDescriptor)
    }
    
    /// Connect to a peer
    ///  - Parameter host: the target host to connect, in IPv4 or IPv6 format, like 127.0.0.1 or ::1
    ///  - Parameter port: the target host port number to connect
    func connect(host: String, port: Int) throws {
        // create IPv6 socket address
        var address = sockaddr_in6(
            sin6_len: UInt8(strideof(sockaddr_in6)),
            sin6_family: UInt8(AF_INET6),
            sin6_port: UInt16(port).bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: try ipAddressToBinary(host),
            sin6_scope_id: 0
        )
        // connect to the host and port
        guard withUnsafePointer(&address, { pointer in
            return Darwin.connect(fileDescriptor, UnsafePointer<sockaddr>(pointer), socklen_t(sizeof(sockaddr_in6))) >= 0
        }) else {
            throw Error.lastSocketError()
        }
    }
    
    /// Send data to peer
    ///  - Parameter bytes: bytes to send
    ///  - Returns: bytes sent to peer
    func send(bytes: [UInt8]) throws -> Int {
        let bytesSent = Darwin.send(fileDescriptor, bytes, bytes.count, Int32(0))
        guard bytesSent >= 0 else {
            throw Error.lastSocketError()
        }
        return bytesSent
    }
    
    /// Read data from peer
    ///  - Parameter size: size of bytes to read
    ///  - Returns: bytes read from peer
    func recv(size: Int) throws -> [UInt8] {
        var bytes = [UInt8](count: size, repeatedValue: 0)
        let bytesRead = bytes.withUnsafeMutableBufferPointer { pointer in
            return Darwin.recv(fileDescriptor, pointer.baseAddress, size, Int32(0))
        }
        guard bytesRead >= 0 else {
            throw Error.lastSocketError()
        }
        return Array(bytes[0..<bytesRead])
    }
    
    // Convert IP address to binary struct
    private func ipAddressToBinary(address: String) throws -> in6_addr {
        // convert interface string into IPv6 address struct
        var binary: in6_addr = in6_addr()
        guard address.withCString({ inet_pton(AF_INET6, $0, &binary) >= 0 }) else {
            throw Error.lastSocketError()
        }
        return binary
    }
}
