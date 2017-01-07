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
    let fileSelect = Glibc.select
#else
    import Darwin
    let fileSelect = Darwin.select
#endif

public final class SelectSelector: Selector {
    enum Error: Swift.Error {
        case keyError(fileDescriptor: Int32)
    }

    private var fileDescriptorMap: [Int32: SelectorKey] = [:]

    public init(selectMaximumEvent: Int = 1024) throws {
        // TODO:
    }

    public func register(_ fileDescriptor: Int32, events: Set<IOEvent>, data: Any?) throws -> SelectorKey {
        // ensure the file descriptor doesn't exist already
        guard fileDescriptorMap[fileDescriptor] == nil else {
            throw Error.keyError(fileDescriptor: fileDescriptor)
        }
        let key = SelectorKey(fileDescriptor: fileDescriptor, events: events, data: data)
        fileDescriptorMap[fileDescriptor] = key
        return key
    }

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
        // TODO:
        return []
    }

    public subscript(fileDescriptor: Int32) -> SelectorKey? {
        // TODO:
        return nil
    }
}
