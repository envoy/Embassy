//
//  TCPSocket.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation


public protocol TCPSocketAddress {

    static var family: TCPSocket.Family { get }
    static var loopbackName: String { get }

    func asData() -> Data

    static func allocate() -> Data
    static func from(address: String, port: UInt16) throws -> TCPSocketAddress

}

/// Class wrapping around TCP/IP socket
public final class TCPSocket {

    public enum Error: Swift.Error {
        case unknownFamily
    }

    public enum Family: Int32 {
        case v4
        case v6
    }


    /// The file descriptor number for socket
    let family: Family
    let fileDescriptor: Int32

    /// Whether is this socket in block mode or not
    var blocking: Bool {
        get {
            return IOUtils.getBlocking(fileDescriptor: fileDescriptor)
        }

        set {
            IOUtils.setBlocking(fileDescriptor: fileDescriptor, blocking: newValue)
        }
    }

    /// Whether to ignore SIGPIPE signal or not
    var ignoreSigPipe: Bool {
        get {
            #if os(Linux)
                return false
            #else
                var value: Int32 = 0
                var size = socklen_t(MemoryLayout<Int32>.size)
                assert(
                    getsockopt(fileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &value, &size) >= 0,
                    "Failed to get SO_NOSIGPIPE, errno=\(errno), message=\(lastErrorDescription())"
                )
                return value == 1
            #endif
        }

        set {
            #if os(Linux)
                // TODO: maybe we should call signal(SIGPIPE, SIG_IGN) here? but it affects
                // whole process
                return
            #else
                var value: Int32 = newValue ? 1 : 0
                assert(
                    setsockopt(
                        fileDescriptor,
                        SOL_SOCKET,
                        SO_NOSIGPIPE,
                        &value,
                        socklen_t(MemoryLayout<Int32>.size)
                        ) >= 0,
                    "Failed to set SO_NOSIGPIPE, errno=\(errno), message=\(lastErrorDescription())"
                )
            #endif
        }
    }

    convenience init(boundToPort port: Int, onInterface interface: String, addressReusable: Bool = true) throws {
        try self.init(familyOf: interface)
        try bind(port: port, interface: interface, addressReusable: addressReusable)
    }

    convenience init(familyOf address: String) throws {
        try self.init(family: Family.from(address: address))
    }

    init(family: Family, blocking: Bool = false) throws {
        self.family = family
        #if os(Linux)
            let socketType = Int32(SOCK_STREAM.rawValue)
        #else
            let socketType = SOCK_STREAM
        #endif
        fileDescriptor = SystemLibrary.socket(family.constant, socketType, 0)
        guard fileDescriptor >= 0 else {
            throw OSError.lastIOError()
        }
        self.blocking = blocking
    }

    init(family: Family, fileDescriptor: Int32, blocking: Bool = false) {
        self.family = family
        self.fileDescriptor = fileDescriptor
        self.blocking = blocking
    }

    deinit {
        close()
    }

    private func addressType() throws -> TCPSocketAddress.Type {
        switch family {
        case .v4: return sockaddr_in.self
        case .v6: return sockaddr_in6.self
        }
    }

    /// Bind the socket at given port and interface
    ///  - Parameter port: port number to bind to
    ///  - Parameter interface: networking interface to bind to, in IPv6 format
    ///  - Parameter addressReusable: should we make address reusable
    func bind(port: Int, interface: String? = nil, addressReusable: Bool = true) throws {
        let addressType = try self.addressType()
        let interface = interface ?? addressType.loopbackName
        // make address reusable
        if addressReusable {
            var reuse = Int32(1)
            guard setsockopt(
                fileDescriptor,
                SOL_SOCKET,
                SO_REUSEADDR,
                &reuse,
                socklen_t(MemoryLayout<Int32>.size)
            ) >= 0 else {
                throw OSError.lastIOError()
            }
        }
        // create socket address
        var address = try addressType.from(address: interface, port: UInt16(port)).asData()
        // bind the address and port on socket
        guard address.withUnsafeBytes({ (bytesPointer: UnsafePointer<UInt8>) in
            return bytesPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                return SystemLibrary.bind(fileDescriptor, pointer, socklen_t(address.count)) >= 0
            }
        }) else {
            throw OSError.lastIOError()
        }
    }

    /// Listen incomming connections
    ///  - Parameter backlog: maximum backlog of incoming connections
    func listen(backlog: Int = Int(SOMAXCONN)) throws {
        guard SystemLibrary.listen(fileDescriptor, Int32(backlog)) != -1 else {
            throw OSError.lastIOError()
        }
    }

    /// Accept a new connection
    func accept() throws -> TCPSocket {
        var address = try addressType().allocate()
        var size = socklen_t(0)
        let clientFileDescriptor = address.withUnsafeMutableBytes { (bytesPointer: UnsafeMutablePointer<UInt8>) in
            return bytesPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                return SystemLibrary.accept(fileDescriptor, pointer, &size)
            }
        }
        guard clientFileDescriptor >= 0 else {
            throw OSError.lastIOError()
        }
        return TCPSocket(family: family, fileDescriptor: clientFileDescriptor)
    }

    /// Connect to a peer
    ///  - Parameter host: the target host to connect, in IPv4 or IPv6 format, like 127.0.0.1 or ::1
    ///  - Parameter port: the target host port number to connect
    func connect(host: String? = nil, port: Int) throws {
        let addressType = try self.addressType()
        let host = host ?? addressType.loopbackName
        var address = try addressType.from(address: host, port: UInt16(port)).asData()
        let connectResult = address.withUnsafeBytes { (bytesPointer: UnsafePointer<UInt8>) in
            return bytesPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                return SystemLibrary.connect(fileDescriptor, pointer, socklen_t(address.count))
            }
        }
        guard connectResult >= 0 || errno == EINPROGRESS else {
            throw OSError.lastIOError()
        }
    }

    /// Send data to peer
    ///  - Parameter data: data bytes to send
    ///  - Returns: bytes sent to peer
    @discardableResult
    func send(data: Data) throws -> Int {
        let bytesSent = data.withUnsafeBytes { pointer in
            SystemLibrary.send(fileDescriptor, pointer, data.count, Int32(0))
        }
        guard bytesSent >= 0 else {
            throw OSError.lastIOError()
        }
        return bytesSent
    }

    /// Read data from peer
    ///  - Parameter size: size of bytes to read
    ///  - Returns: bytes read from peer
    func recv(size: Int) throws -> Data {
        var bytes = Data(count: size)
        let bytesRead = bytes.withUnsafeMutableBytes { pointer in
            return SystemLibrary.recv(fileDescriptor, pointer, size, Int32(0))
        }
        guard bytesRead >= 0 else {
            throw OSError.lastIOError()
        }
        return bytes.subdata(in: 0..<bytesRead)
    }

    /// Close the socket
    func close() {
        _ = SystemLibrary.shutdown(fileDescriptor, Int32(SHUT_WR))
        _ = SystemLibrary.close(fileDescriptor)
    }

    func getPeerName() throws -> (String, Int) {
        return try getName(function: getpeername)
    }

    func getSockName() throws -> (String, Int) {
        return try getName(function: getsockname)
    }

    private func getName(
        function: (Int32, UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) -> Int32
    ) throws -> (String, Int) {
        var address = sockaddr_storage()
        var size = socklen_t(MemoryLayout<sockaddr_storage>.size)
        return try withUnsafeMutablePointer(to: &address) { pointer in
            let result = pointer.withMemoryRebound(
                to: sockaddr.self,
                capacity: Int(size)
            ) { addressptr in
                return function(fileDescriptor, addressptr, &size)
            }
            guard result >= 0 else {
                throw OSError.lastIOError()
            }
            switch Int32(pointer.pointee.ss_family) {
            case AF_INET:
                return try pointer.withMemoryRebound(
                    to: sockaddr_in.self,
                    capacity: MemoryLayout<sockaddr_in>.size
                ) { addressptr in
                    return (
                        try structToAddress(
                            addrStruct: addressptr.pointee.sin_addr,
                            family: AF_INET,
                            addressLength: INET_ADDRSTRLEN
                        ),
                        Int(SystemLibrary.ntohs(addressptr.pointee.sin_port))
                    )
                }
            case AF_INET6:
                return try pointer.withMemoryRebound(
                    to: sockaddr_in6.self,
                    capacity: MemoryLayout<sockaddr_in6>.size
                ) { addressptr in
                    return (
                        try structToAddress(
                            addrStruct: addressptr.pointee.sin6_addr,
                            family: AF_INET6,
                            addressLength: INET6_ADDRSTRLEN
                        ),
                        Int(SystemLibrary.ntohs(addressptr.pointee.sin6_port))
                    )
                }
            default:
                fatalError("Unsupported address family")
            }
        }
    }

    private func structToAddress<StructType>(
        addrStruct: StructType,
        family: Int32,
        addressLength: Int32
    ) throws -> String {
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
        if let index = address.firstIndex(of: 0) {
            address = address.subdata(in: 0 ..< index)
        }
        return String(data: address, encoding: .utf8)!
    }
}


extension TCPSocket.Family {

    var constant: Int32 {
        switch self {
        case .v4: return AF_INET
        case .v6: return AF_INET6
        }
    }

    fileprivate static func from(address: String) throws -> TCPSocket.Family {
        var binary: in_addr = in_addr()
        if (address.withCString { return inet_pton(AF_INET, $0, &binary) } == 1) { return .v4 }
        if (address.withCString { return inet_pton(AF_INET6, $0, &binary) } == 1) { return .v6 }
        throw TCPSocket.Error.unknownFamily
    }

}


extension sockaddr_in: TCPSocketAddress {

    public static let family = TCPSocket.Family.v4
    public static let loopbackName = "127.0.0.1"

    public func asData() -> Data {
        var address = self
        return withUnsafeBytes(of: &address) {
            return Data(bytes: $0.baseAddress!, count: $0.count)
        }
    }

    public static func allocate() -> Data {
        return Data(capacity: MemoryLayout<sockaddr_in>.size)
    }

    // convert interface string into IPv4 address struct
    public static func from(address: String, port: UInt16) throws -> TCPSocketAddress {
        var binary: in_addr = in_addr()
        guard address.withCString({ inet_pton(AF_INET, $0, &binary) >= 0 }) else {
            throw OSError.lastIOError()
        }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = UInt8(sockaddr_in.family.constant)
        address.sin_port = CFSwapInt16HostToBig(port)
        address.sin_addr = binary
        return address
    }

}


extension sockaddr_in6: TCPSocketAddress {

    public static let family = TCPSocket.Family.v6
    public static let loopbackName = "::"

    public func asData() -> Data {
        var address = self
        return withUnsafeBytes(of: &address) {
            return Data(bytes: $0.baseAddress!, count: $0.count)
        }
    }

    public static func allocate() -> Data {
        return Data(capacity: MemoryLayout<sockaddr_in6>.size)
    }

    // convert interface string into IPv6 address struct
    public static func from(address: String, port: UInt16) throws -> TCPSocketAddress {
        var binary: in6_addr = in6_addr()
        guard address.withCString({ inet_pton(AF_INET6, $0, &binary) >= 0 }) else {
            throw OSError.lastIOError()
        }
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = UInt8(sockaddr_in6.family.constant)
        address.sin6_port = CFSwapInt16HostToBig(port)
        address.sin6_addr = binary
        return address
    }

}
