//
//  KqueueSelector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Thread confinement: `register`/`unregister`/`select` mutate unsynchronized state and must only
/// be called from the thread running the owning `EventLoop`.
public final class KqueueSelector: Selector, @unchecked Sendable {
    enum Error: Swift.Error {
        case keyError(fileDescriptor: Int32)
    }

    // the maximum event number to select from kqueue at once (one kevent call)
    private let selectMaximumEvent: Int
    private let kqueue: Int32
    private var fileDescriptorMap: [Int32: SelectorKey] = [:]
    // reusable buffer for kevent() to write ready events into; allocated once
    // rather than on every select() call
    private var readyEvents: [Darwin.kevent]

    public init(selectMaximumEvent: Int = 1024) throws {
        kqueue = Darwin.kqueue()
        guard kqueue >= 0 else {
            throw OSError.lastIOError()
        }
        self.selectMaximumEvent = selectMaximumEvent
        readyEvents = [Darwin.kevent](repeating: Darwin.kevent(), count: selectMaximumEvent)
    }

    deinit {
        close()
    }

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

        var kevents: [Darwin.kevent] = []
        for event in events {
            let filter: Int16
            switch event {
            case .read:
                filter = Int16(EVFILT_READ)
            case .write:
                filter = Int16(EVFILT_WRITE)
            }
            let kevent = Darwin.kevent(
                ident: UInt(fileDescriptor),
                filter: filter,
                flags: UInt16(EV_ADD),
                fflags: UInt32(0),
                data: Int(0),
                udata: nil
            )
            kevents.append(kevent)
        }

        // register events to kqueue
        guard kevents.withUnsafeMutableBufferPointer({ pointer in
            kevent(kqueue, pointer.baseAddress, Int32(pointer.count), nil, Int32(0), nil) >= 0
        }) else {
            throw OSError.lastIOError()
        }
        return key
    }

    @discardableResult
    public func unregister(_ fileDescriptor: Int32) throws -> SelectorKey {
        // ensure the file descriptor exists
        guard let key = fileDescriptorMap[fileDescriptor] else {
            throw Error.keyError(fileDescriptor: fileDescriptor)
        }
        fileDescriptorMap.removeValue(forKey: fileDescriptor)
        var kevents: [Darwin.kevent] = []
        for event in key.events {
            let filter: Int16
            switch event {
            case .read:
                filter = Int16(EVFILT_READ)
            case .write:
                filter = Int16(EVFILT_WRITE)
            }
            let kevent = Darwin.kevent(
                ident: UInt(fileDescriptor),
                filter: filter,
                flags: UInt16(EV_DELETE),
                fflags: UInt32(0),
                data: Int(0),
                udata: nil
            )
            kevents.append(kevent)
        }

        // unregister events from kqueue
        guard kevents.withUnsafeMutableBufferPointer({ pointer in
            kevent(kqueue, pointer.baseAddress, Int32(pointer.count), nil, Int32(0), nil) >= 0
        }) else {
            throw OSError.lastIOError()
        }
        return key
    }

    public func close() {
        _ = Darwin.close(kqueue)
    }

    public func select(timeout: TimeInterval?) throws -> [(SelectorKey, Set<IOEvent>)] {
        var timeSpec: timespec?
        if let timeout = timeout {
            if timeout > 0 {
                var integer = 0.0
                let nsec = Int(modf(timeout, &integer) * Double(NSEC_PER_SEC))
                timeSpec = timespec(tv_sec: Int(timeout), tv_nsec: nsec)
            } else {
                timeSpec = timespec()
            }
        }

        let eventCount: Int32 = readyEvents.withUnsafeMutableBufferPointer { pointer in
            return withUnsafeOptionalPointer(to: &timeSpec) { timeSpecPointer in
                return kevent(
                    kqueue,
                    nil,
                    0,
                    pointer.baseAddress,
                    Int32(selectMaximumEvent),
                    timeSpecPointer
                )
            }
        }
        guard eventCount >= 0 else {
            throw OSError.lastIOError()
        }

        // kqueue reports read and write readiness as separate events; merge them
        // per file descriptor so each key appears once in the result
        var result: [(SelectorKey, Set<IOEvent>)] = []
        result.reserveCapacity(Int(eventCount))
        var indexByFileDescriptor: [Int32: Int] = [:]
        for index in 0..<Int(eventCount) {
            let event = readyEvents[index]
            let fileDescriptor = Int32(event.ident)
            let ioEvent: IOEvent
            switch Int32(event.filter) {
            case EVFILT_READ:
                ioEvent = .read
            case EVFILT_WRITE:
                ioEvent = .write
            default:
                continue
            }
            if let existing = indexByFileDescriptor[fileDescriptor] {
                result[existing].1.insert(ioEvent)
            } else if let key = fileDescriptorMap[fileDescriptor] {
                indexByFileDescriptor[fileDescriptor] = result.count
                result.append((key, [ioEvent]))
            }
        }
        return result
    }

    public subscript(fileDescriptor: Int32) -> SelectorKey? {
        get {
            return fileDescriptorMap[fileDescriptor]
        }
    }

    private func withUnsafeOptionalPointer<T, Result>(to: inout T?, body: (UnsafePointer<T>?) throws -> Result) rethrows -> Result {
        if to != nil {
            return try withUnsafePointer(to: &to!) { try body($0) }
        } else {
            return try body(nil)
        }
    }

}

