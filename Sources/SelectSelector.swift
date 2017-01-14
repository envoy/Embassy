//
//  SelectSelector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 1/6/17.
//  Copyright © 2017 Fang-Pen Lin. All rights reserved.
//

import Foundation

#if os(Linux)
    import Glibc
    let fdSetSize = FD_SETSIZE
    let fileSelect = Glibc.select
    func fdSet(fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd / 16)
        let bitOffset = Int(fd % 16)
        let mask = 1 << bitOffset
        switch intOffset {
        case 0: set.__fds_bits.0 = set.__fds_bits.0 | mask
        case 1: set.__fds_bits.1 = set.__fds_bits.1 | mask
        case 2: set.__fds_bits.2 = set.__fds_bits.2 | mask
        case 3: set.__fds_bits.3 = set.__fds_bits.3 | mask
        case 4: set.__fds_bits.4 = set.__fds_bits.4 | mask
        case 5: set.__fds_bits.5 = set.__fds_bits.5 | mask
        case 6: set.__fds_bits.6 = set.__fds_bits.6 | mask
        case 7: set.__fds_bits.7 = set.__fds_bits.7 | mask
        case 8: set.__fds_bits.8 = set.__fds_bits.8 | mask
        case 9: set.__fds_bits.9 = set.__fds_bits.9 | mask
        case 10: set.__fds_bits.10 = set.__fds_bits.10 | mask
        case 11: set.__fds_bits.11 = set.__fds_bits.11 | mask
        case 12: set.__fds_bits.12 = set.__fds_bits.12 | mask
        case 13: set.__fds_bits.13 = set.__fds_bits.13 | mask
        case 14: set.__fds_bits.14 = set.__fds_bits.14 | mask
        case 15: set.__fds_bits.15 = set.__fds_bits.15 | mask
        default: break
        }
    }

    func fdIsSet(fd: Int32, set: inout fd_set) -> Bool {
        let intOffset = Int(fd / 32)
        let bitOffset = Int(fd % 32)
        let mask = Int(1 << bitOffset)

        switch intOffset {
        case 0: return set.__fds_bits.0 & mask != 0
        case 1: return set.__fds_bits.1 & mask != 0
        case 2: return set.__fds_bits.2 & mask != 0
        case 3: return set.__fds_bits.3 & mask != 0
        case 4: return set.__fds_bits.4 & mask != 0
        case 5: return set.__fds_bits.5 & mask != 0
        case 6: return set.__fds_bits.6 & mask != 0
        case 7: return set.__fds_bits.7 & mask != 0
        case 8: return set.__fds_bits.8 & mask != 0
        case 9: return set.__fds_bits.9 & mask != 0
        case 10: return set.__fds_bits.10 & mask != 0
        case 11: return set.__fds_bits.11 & mask != 0
        case 12: return set.__fds_bits.12 & mask != 0
        case 13: return set.__fds_bits.13 & mask != 0
        case 14: return set.__fds_bits.14 & mask != 0
        case 15: return set.__fds_bits.15 & mask != 0
        default: return false
        }
    }

#else
    import Darwin
    let fdSetSize = __DARWIN_FD_SETSIZE
    let fileSelect = Darwin.select

    func fdSet(fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 | mask
        case 1: set.fds_bits.1 = set.fds_bits.1 | mask
        case 2: set.fds_bits.2 = set.fds_bits.2 | mask
        case 3: set.fds_bits.3 = set.fds_bits.3 | mask
        case 4: set.fds_bits.4 = set.fds_bits.4 | mask
        case 5: set.fds_bits.5 = set.fds_bits.5 | mask
        case 6: set.fds_bits.6 = set.fds_bits.6 | mask
        case 7: set.fds_bits.7 = set.fds_bits.7 | mask
        case 8: set.fds_bits.8 = set.fds_bits.8 | mask
        case 9: set.fds_bits.9 = set.fds_bits.9 | mask
        case 10: set.fds_bits.10 = set.fds_bits.10 | mask
        case 11: set.fds_bits.11 = set.fds_bits.11 | mask
        case 12: set.fds_bits.12 = set.fds_bits.12 | mask
        case 13: set.fds_bits.13 = set.fds_bits.13 | mask
        case 14: set.fds_bits.14 = set.fds_bits.14 | mask
        case 15: set.fds_bits.15 = set.fds_bits.15 | mask
        case 16: set.fds_bits.16 = set.fds_bits.16 | mask
        case 17: set.fds_bits.17 = set.fds_bits.17 | mask
        case 18: set.fds_bits.18 = set.fds_bits.18 | mask
        case 19: set.fds_bits.19 = set.fds_bits.19 | mask
        case 20: set.fds_bits.20 = set.fds_bits.20 | mask
        case 21: set.fds_bits.21 = set.fds_bits.21 | mask
        case 22: set.fds_bits.22 = set.fds_bits.22 | mask
        case 23: set.fds_bits.23 = set.fds_bits.23 | mask
        case 24: set.fds_bits.24 = set.fds_bits.24 | mask
        case 25: set.fds_bits.25 = set.fds_bits.25 | mask
        case 26: set.fds_bits.26 = set.fds_bits.26 | mask
        case 27: set.fds_bits.27 = set.fds_bits.27 | mask
        case 28: set.fds_bits.28 = set.fds_bits.28 | mask
        case 29: set.fds_bits.29 = set.fds_bits.29 | mask
        case 30: set.fds_bits.30 = set.fds_bits.30 | mask
        case 31: set.fds_bits.31 = set.fds_bits.31 | mask
        default: break
        }
    }

    func fdIsSet(fd: Int32, set: inout fd_set) -> Bool {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        switch intOffset {
        case 0: return set.fds_bits.0 & mask != 0
        case 1: return set.fds_bits.1 & mask != 0
        case 2: return set.fds_bits.2 & mask != 0
        case 3: return set.fds_bits.3 & mask != 0
        case 4: return set.fds_bits.4 & mask != 0
        case 5: return set.fds_bits.5 & mask != 0
        case 6: return set.fds_bits.6 & mask != 0
        case 7: return set.fds_bits.7 & mask != 0
        case 8: return set.fds_bits.8 & mask != 0
        case 9: return set.fds_bits.9 & mask != 0
        case 10: return set.fds_bits.10 & mask != 0
        case 11: return set.fds_bits.11 & mask != 0
        case 12: return set.fds_bits.12 & mask != 0
        case 13: return set.fds_bits.13 & mask != 0
        case 14: return set.fds_bits.14 & mask != 0
        case 15: return set.fds_bits.15 & mask != 0
        case 16: return set.fds_bits.16 & mask != 0
        case 17: return set.fds_bits.17 & mask != 0
        case 18: return set.fds_bits.18 & mask != 0
        case 19: return set.fds_bits.19 & mask != 0
        case 20: return set.fds_bits.20 & mask != 0
        case 21: return set.fds_bits.21 & mask != 0
        case 22: return set.fds_bits.22 & mask != 0
        case 23: return set.fds_bits.23 & mask != 0
        case 24: return set.fds_bits.24 & mask != 0
        case 25: return set.fds_bits.25 & mask != 0
        case 26: return set.fds_bits.26 & mask != 0
        case 27: return set.fds_bits.27 & mask != 0
        case 28: return set.fds_bits.28 & mask != 0
        case 29: return set.fds_bits.29 & mask != 0
        case 30: return set.fds_bits.30 & mask != 0
        case 31: return set.fds_bits.31 & mask != 0
        default: return false
        }
    }
#endif

public final class SelectSelector: Selector {
    enum Error: Swift.Error {
        case keyError(fileDescriptor: Int32)
    }

    private var fileDescriptorMap: [Int32: SelectorKey] = [:]

    @discardableResult
    public func register(
        _ fileDescriptor: Int32,
        events: Set<IOEvent>,
        data: Any?
    ) throws -> SelectorKey {
        // ensure the file descriptor doesn't exist already
        guard fileDescriptorMap[fileDescriptor] == nil else {
            throw Error.keyError(fileDescriptor: fileDescriptor)
        }
        let key = SelectorKey(fileDescriptor: fileDescriptor, events: events, data: data)
        fileDescriptorMap[fileDescriptor] = key
        return key
    }

    @discardableResult
    public func unregister(_ fileDescriptor: Int32) throws -> SelectorKey {
        // ensure the file descriptor exists
        guard let key = fileDescriptorMap[fileDescriptor] else {
            throw Error.keyError(fileDescriptor: fileDescriptor)
        }
        fileDescriptorMap.removeValue(forKey: fileDescriptor)
        return key
    }

    public func close() {
        // TODO:
    }

    public func select(timeout: TimeInterval?) throws -> [(SelectorKey, Set<IOEvent>)] {
        var readSet = fd_set()
        var writeSet = fd_set()

        for (fd, key) in fileDescriptorMap {
            if key.events.contains(.read) {
                fdSet(fd: fd, set: &readSet)
            }
            if key.events.contains(.write) {
                fdSet(fd: fd, set: &writeSet)
            }
        }
        var timeoutVal: timeval = timeval(tv_sec: 0, tv_usec: 0)
        if let timeout = timeout {
            #if os(Linux)
            timeoutVal.tv_sec = Int(timeout)
            timeoutVal.tv_usec = Int(Int(timeout * 1000) - Int(timeout) * 1000)
            #else
            // TODO: not sure is the calculation correct here
            timeoutVal.tv_sec = Int(timeout)
            timeoutVal.tv_usec = __darwin_suseconds_t(Int(timeout * 1000) - Int(timeout) * 1000)
            #endif
        }
        let status = fileSelect(fdSetSize, &readSet, &writeSet, nil, &timeoutVal)
        switch status {
        case 0:
            // TODO: timeout?
            return []
        // Error
        case -1:
            // TODO:
            break
        default:
            break
        }

        var result: [(SelectorKey, Set<IOEvent>)] = []
        for (fd, key) in fileDescriptorMap {
            var events = Set<IOEvent>()
            if fdIsSet(fd: fd, set: &readSet) {
                events.insert(.read)
            }
            if fdIsSet(fd: fd, set: &writeSet) {
                events.insert(.write)
            }
            if events.count > 0 {
                result.append((key, events))
            }
        }
        return result
    }

    public subscript(fileDescriptor: Int32) -> SelectorKey? {
        get {
            return fileDescriptorMap[fileDescriptor]
        }
    }
}
