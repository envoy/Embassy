//
//  TCPSocket.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
let htons  = isLittleEndian ? _OSSwapInt16 : { $0 }
let ntohs  = isLittleEndian ? _OSSwapInt16 : { $0 }

/// Class wrapping around TCP/IPv6 socket
public final class TCPSocket {
    /// The file descriptor number for socket
    let fileDescriptor: Int32

    /// Whether is this socket in block mode or not
    var blocking: Bool {
        get {
            return IOUtils.getBlocking(fileDescriptor)
        }

        set {
            IOUtils.setBlocking(fileDescriptor, blocking: newValue)
        }
    }

    /// Whether to ignore SIGPIPE signal or not
    var ignoreSigPipe: Bool {
        get {
            var value: Int32 = 0
            var size = socklen_t(MemoryLayout<Int32>.size)
            assert(
                getsockopt(fileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &value, &size) >= 0,
                "Failed to get SO_NOSIGPIPE, errno=\(errno), message=\(lastErrorDescription())"
            )
            return value == 1
        }

        set {
            var value: Int32 = newValue ? 1 : 0
            assert(
                setsockopt(fileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size)) >= 0,
                "Failed to set SO_NOSIGPIPE, errno=\(errno), message=\(lastErrorDescription())"
            )
        }
    }

    init(blocking: Bool = false) throws {
        fileDescriptor = socket(AF_INET6, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw OSError.lastIOError()
        }
        self.blocking = blocking
    }

    init(fileDescriptor: Int32, blocking: Bool = false) {
        self.fileDescriptor = fileDescriptor
        self.blocking = blocking
    }

    deinit {
        close()
    }

    /// Bind the socket at given port and interface
    ///  - Parameter port: port number to bind to
    ///  - Parameter interface: networking interface to bind to, in IPv6 format
    ///  - Parameter addressReusable: should we make address reusable
    func bind(_ port: Int, interface: String = "::", addressReusable: Bool = true) throws {
        // make address reusable
        if addressReusable {
            var reuse = Int32(1)
            guard setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) >= 0 else {
                throw OSError.lastIOError()
            }
        }
        // create IPv6 socket address
        var address = sockaddr_in6(
            sin6_len: UInt8(MemoryLayout<sockaddr_in6>.stride),
            sin6_family: UInt8(AF_INET6),
            sin6_port: UInt16(port).bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: try ipAddressToStruct(interface),
            sin6_scope_id: 0
        )
        let size = socklen_t(MemoryLayout<sockaddr_in6>.size)
        // bind the address and port on socket
        guard withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { pointer in
                return Darwin.bind(fileDescriptor, pointer, size) >= 0
            }
        }) else {
            throw OSError.lastIOError()
        }
    }

    /// Listen incomming connections
    ///  - Parameter backlog: maximum backlog of incoming connections
    func listen(_ backlog: Int = Int(SOMAXCONN)) throws {
        guard Darwin.listen(fileDescriptor, Int32(backlog)) != -1 else {
            throw OSError.lastIOError()
        }
    }

    /// Accept a new connection
    func accept() throws -> TCPSocket {
        var address = sockaddr_in6()
        var size = socklen_t(MemoryLayout<sockaddr_in6>.size)
        let clientFileDescriptor = withUnsafeMutablePointer(to: &address) { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { pointer in
                return Darwin.accept(fileDescriptor, pointer, &size)
            }
        }
        guard clientFileDescriptor >= 0 else {
            throw OSError.lastIOError()
        }
        return TCPSocket(fileDescriptor: clientFileDescriptor)
    }

    /// Connect to a peer
    ///  - Parameter host: the target host to connect, in IPv4 or IPv6 format, like 127.0.0.1 or ::1
    ///  - Parameter port: the target host port number to connect
    func connect(_ host: String, port: Int) throws {
        // create IPv6 socket address
        var address = sockaddr_in6(
            sin6_len: UInt8(MemoryLayout<sockaddr_in6>.stride),
            sin6_family: UInt8(AF_INET6),
            sin6_port: UInt16(port).bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: try ipAddressToStruct(host),
            sin6_scope_id: 0
        )
        let size = socklen_t(MemoryLayout<sockaddr_in6>.size)
        // connect to the host and port
        let connectResult = withUnsafePointer(to: &address) { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { pointer in
                return Darwin.connect(fileDescriptor, pointer, size)
            }
        }
        guard connectResult >= 0 || errno == EINPROGRESS else {
            throw OSError.lastIOError()
        }
    }

    /// Send data to peer
    ///  - Parameter bytes: bytes to send
    ///  - Returns: bytes sent to peer
    @discardableResult
    func send(_ bytes: Data) throws -> Int {
        let bytesSent = bytes.withUnsafeBytes { pointer in
            Darwin.send(fileDescriptor, pointer, bytes.count, Int32(0))
        }
        guard bytesSent >= 0 else {
            throw OSError.lastIOError()
        }
        return bytesSent
    }

    /// Read data from peer
    ///  - Parameter size: size of bytes to read
    ///  - Returns: bytes read from peer
    func recv(_ size: Int) throws -> Data {
        var bytes = Data(count: size)
        let bytesRead = bytes.withUnsafeMutableBytes { pointer in
            return Darwin.recv(fileDescriptor, pointer, size, Int32(0))
        }
        guard bytesRead >= 0 else {
            throw OSError.lastIOError()
        }
        return bytes.subdata(in: 0..<bytesRead)
    }

    /// Close the socket
    func close() {
        _ = Darwin.shutdown(fileDescriptor, SHUT_WR)
        _ = Darwin.close(fileDescriptor)
    }

    func getPeerName() throws -> (String, Int) {
        return try getName(Darwin.getpeername)
    }

    func getSockName() throws -> (String, Int) {
        return try getName(Darwin.getsockname)
    }
    
    private func getName(_ function: (Int32, UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) -> Int32) throws -> (String, Int) {
        var address = sockaddr_storage()
        var size = socklen_t(MemoryLayout<sockaddr_storage>.size)
        return try withUnsafeMutablePointer(to: &address) { pointer in
            let result = pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { addressptr in
                return function(fileDescriptor, addressptr, &size)
            }
            guard result >= 0 else {
                throw OSError.lastIOError()
            }
            switch Int32(address.ss_family) {
            case AF_INET:
                return try pointer.withMemoryRebound(to: sockaddr_in.self, capacity: MemoryLayout<sockaddr_in>.size) { addressptr in
                    return (try structToAddress(addressptr.pointee.sin_addr, family: AF_INET, addressLength: INET_ADDRSTRLEN), Int(ntohs(addressptr.pointee.sin_port)))
                }
            case AF_INET6:
                return try pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: MemoryLayout<sockaddr_in6>.size) { addressptr in
                    return (try structToAddress(addressptr.pointee.sin6_addr, family: AF_INET6, addressLength: INET6_ADDRSTRLEN), Int(ntohs(addressptr.pointee.sin6_port)))
                }
            default:
                fatalError("Unsupported address family")
            }
        }
    }
    
    // Convert IP address to binary struct
    private func ipAddressToStruct(_ address: String) throws -> in6_addr {
        // convert interface string into IPv6 address struct
        var binary: in6_addr = in6_addr()
        guard address.withCString({ inet_pton(AF_INET6, $0, &binary) >= 0 }) else {
            throw OSError.lastIOError()
        }
        return binary
    }
    
    private func structToAddress<StructType>(_ addrStruct: StructType, family: Int32, addressLength: Int32) throws -> String {
        var addrStruct = addrStruct
        // convert address struct into address string
        var address = Data(count: Int(addressLength))
        guard address.withUnsafeMutableBytes({ pointer in
            inet_ntop(
                family,
                &addrStruct,
                pointer,
                socklen_t(addressLength)
            ) != nil
        }) else {
            throw OSError.lastIOError()
        }
        if let index = address.index(of: 0) {
            address = address.subdata(in: 0 ..< index)
        }
        return String(data: address, encoding: .utf8)!
    }
}
