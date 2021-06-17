//
//  KqueueSelector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

#if !os(Linux)

public final class KqueueSelector: Selector {
    enum Error: Swift.Error {
        case keyError(fileDescriptor: Int32)
    }

    // the maximum event number to select from kqueue at once (one kevent call)
    private let selectMaximumEvent: Int
    private let kqueue: Int32
    private var fileDescriptorMap: [Int32: SelectorKey] = [:]

    public init(selectMaximumEvent: Int = 1024) throws {
        kqueue = Darwin.kqueue()
        guard kqueue >= 0 else {
            throw OSError.lastIOError()
        }
        self.selectMaximumEvent = selectMaximumEvent
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

        var kevents = Array<Darwin.kevent>(repeating: Darwin.kevent(), count: selectMaximumEvent)
        let eventCount:Int32 = kevents.withUnsafeMutableBufferPointer { pointer in
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

        var fileDescriptorIOEvents = [Int32: Set<IOEvent>]()
        for index in 0..<Int(eventCount) {
            let event = kevents[index]
            let fileDescriptor = Int32(event.ident)
            var ioEvents = fileDescriptorIOEvents[fileDescriptor] ?? Set<IOEvent>()
            if event.filter == Int16(EVFILT_READ) {
                ioEvents.insert(.read)
            } else if event.filter == Int16(EVFILT_WRITE) {
                ioEvents.insert(.write)
            }
            fileDescriptorIOEvents[fileDescriptor] = ioEvents
        }
        let fdMap = fileDescriptorMap
        return fileDescriptorIOEvents.compactMap { [weak self] event in
            fdMap[event.0].map { ($0, event.1) } ?? nil
        }
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

#endif
