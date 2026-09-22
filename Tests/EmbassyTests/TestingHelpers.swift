//
//  TestingHelpers.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import XCTest

@testable import Embassy

import Darwin
typealias TestingSelector = KqueueSelector

/// Base unit for sequencing events in tests. Loopback IO completes in well
/// under a millisecond, so steps only need to be far enough apart to order
/// events deterministically, not to wait for anything real.
let tick: TimeInterval = 0.1

/// Timing slack for `assertExecutingTime`, in seconds. kqueue timeouts and GCD
/// deadlines are accurate to a few milliseconds.
let tickAccuracy: TimeInterval = 0.05

extension DispatchTime {
    /// Deadline `ticks` ticks from now
    static func inTicks(_ ticks: Double) -> DispatchTime {
        .now() + ticks * tick
    }
}

/// Find an available localhost TCP port from 1024-65535 and return it.
/// Ref: https://github.com/pytest-dev/pytest-asyncio/blob/412c63776b32229ed8320e6c7ea920d7498cd695/pytest_asyncio/plugin.py#L103-L107
func getUnusedTCPPort() throws -> Int {
    var interfaceAddress: in_addr = in_addr()
    guard "127.0.0.1".withCString({ inet_pton(AF_INET, $0, &interfaceAddress) >= 0 }) else {
        throw OSError.lastIOError()
    }

    let socketType = SOCK_STREAM
    let fileDescriptor = socket(AF_INET, socketType, 0)
    guard fileDescriptor >= 0 else {
        throw OSError.lastIOError()
    }
    defer {
        close(fileDescriptor)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = UInt16(0).bigEndian
    address.sin_addr = interfaceAddress
    address.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
    let addressSize = socklen_t(MemoryLayout<sockaddr_in>.size)
    // given port 0, and bind, it will find us an available port
    guard withUnsafePointer(to: &address, { pointer in
        return pointer.withMemoryRebound(
            to: sockaddr.self,
            capacity: 1
        ) { pointer in
            return Darwin.bind(fileDescriptor, pointer, addressSize) >= 0
        }
    }) else {
        throw OSError.lastIOError()
    }

    var socketAddress = sockaddr_in()
    var socketAddressSize = socklen_t(MemoryLayout<sockaddr_in>.size)
    guard withUnsafeMutablePointer(to: &socketAddress, { pointer in
        return pointer.withMemoryRebound(
            to: sockaddr.self,
            capacity: 1
        ) { pointer in
            return getsockname(fileDescriptor, pointer, &socketAddressSize) >= 0
        }
    }) else {
        throw OSError.lastIOError()
    }
    return Int(UInt16(bigEndian: socketAddress.sin_port))
}

func makeRandomString(_ length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let endIndex = UInt32(letters.count - 1)
    let result: [Any?] = Array(repeating: nil, count: length)
    return String(result.map({ _ in
      letters[String.Index(utf16Offset: Int(arc4random_uniform(endIndex)), in: letters)]
    }))
}

extension XCTestCase {
    @discardableResult
    func assertExecutingTime<T>(
        _ time: TimeInterval,
        accuracy: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line,
        closure: () -> T
    ) -> T {
        let begin = Date()
        let result = closure()
        let elapsed = Date().timeIntervalSince(begin)
        XCTAssertEqual(
            elapsed,
            time,
            accuracy: accuracy,
            "Wrong executing time",
            file: file,
            line: line
        )
        return result
    }
}

struct FileDescriptorEvent {
    let fileDescriptor: Int32
    let ioEvent: IOEvent
}

extension FileDescriptorEvent: Equatable {
}

func == (lhs: FileDescriptorEvent, rhs: FileDescriptorEvent) -> Bool {
    return lhs.fileDescriptor == rhs.fileDescriptor && lhs.ioEvent == rhs.ioEvent
}

extension FileDescriptorEvent: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(fileDescriptor)
        hasher.combine(ioEvent)
    }
}
