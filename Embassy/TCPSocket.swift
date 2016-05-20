//
//  TCPSocket.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Class wrapping around TCP/IPv6 socket
class TCPSocket {
    /// The file descriptor number for socket
    let fileDescriptor: Int32
    
    init() {
        fileDescriptor = socket(AF_INET6, SOCK_STREAM, 0)
    }
    
    init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }
    
    /// Bind the socket at given port and interface
    ///  - Parameter port: Port number to bind to
    ///  - Parameter interface: Networking interface to bind to, in IPv6 format
    func bind(port: Int, interface: String = "::") throws {
        // convert interface string into IPv6 address struct
        var interfaceAddress: in6_addr = in6_addr()
        guard interface.withCString({ inet_pton(AF_INET6, $0, &interfaceAddress) != -1}) else {
            // TODO: raise error here
            return
        }
        // create IPv6 socket address
        var address = sockaddr_in6(
            sin6_len: UInt8(strideof(sockaddr_in6)),
            sin6_family: UInt8(AF_INET6),
            sin6_port: UInt16(port).bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: interfaceAddress,
            sin6_scope_id: 0
        )
        // bind the address and port on socket
        guard withUnsafePointer(&address, { pointer in
            return Darwin.bind(fileDescriptor, UnsafePointer<sockaddr>(pointer), socklen_t(sizeof(sockaddr_in6)))
        }) != -1 else {
            // TODO: raise error here
            return
        }
    }
    
    func listen(backlog: Int = Int(SOMAXCONN)) throws {
        guard Darwin.listen(fileDescriptor, Int32(backlog)) != -1 else {
            // TODO: raise error here
            return
        }
    }
}
