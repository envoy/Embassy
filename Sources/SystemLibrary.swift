//
//  SystemLibrary.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 1/14/17.
//  Copyright © 2017 Fang-Pen Lin. All rights reserved.
//

import Darwin
import Foundation

/// Collection of system library methods and constants
struct SystemLibrary {
    static let pipe = Darwin.pipe
    static let socket = Darwin.socket
    static let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
    static let htons  = isLittleEndian ? _OSSwapInt16 : { $0 }
    static let ntohs  = isLittleEndian ? _OSSwapInt16 : { $0 }
    static let connect = Darwin.connect
    static let bind = Darwin.bind
    static let listen = Darwin.listen
    static let accept = Darwin.accept
    static let send = Darwin.send
    static let recv = Darwin.recv
    static let read = Darwin.read
    static let shutdown = Darwin.shutdown
    static let close = Darwin.close
    static let getpeername = Darwin.getpeername
    static let getsockname = Darwin.getsockname
}
