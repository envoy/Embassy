//
//  TestingHelpers.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

@testable import Embassy

let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
let htons  = isLittleEndian ? _OSSwapInt16 : { $0 }
let ntohs  = isLittleEndian ? _OSSwapInt16 : { $0 }

/// Find an available localhost TCP port from 1024-65535 and return it.
/// Ref: https://github.com/pytest-dev/pytest-asyncio/blob/412c63776b32229ed8320e6c7ea920d7498cd695/pytest_asyncio/plugin.py#L103-L107
func getUnusedTCPPort() throws -> Int {
    var interfaceAddress: in_addr = in_addr()
    guard "127.0.0.1".withCString({ inet_pton(AF_INET, $0, &interfaceAddress) >= 0 }) else {
        throw TCPSocketError.Error(number: Int(errno), message: TCPSocket.lastErrorDescription())
    }
    
    let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard fileDescriptor >= 0 else {
        throw TCPSocketError.Error(number: Int(errno), message: TCPSocket.lastErrorDescription())
    }
    defer {
        close(fileDescriptor)
    }
    
    var address = sockaddr_in(
        sin_len: UInt8(strideof(sockaddr_in)),
        sin_family: UInt8(AF_INET),
        sin_port: htons(UInt16(0)),
        sin_addr: interfaceAddress,
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )
    // given port 0, and bind, it will find us an available port
    guard withUnsafePointer(&address, { pointer in
        return Darwin.bind(fileDescriptor, UnsafePointer<sockaddr>(pointer), socklen_t(sizeof(sockaddr_in))) >= 0
    }) else {
        throw TCPSocketError.Error(number: Int(errno), message: TCPSocket.lastErrorDescription())
    }
    
    var socketAddress = sockaddr_in()
    var size = socklen_t(sizeof(sockaddr_in))
    guard withUnsafeMutablePointer(&socketAddress, { pointer in
        return getsockname(fileDescriptor, UnsafeMutablePointer<sockaddr>(pointer), &size) >= 0
    }) else {
        throw TCPSocketError.Error(number: Int(errno), message: TCPSocket.lastErrorDescription())
    }
    return Int(ntohs(socketAddress.sin_port))
}
