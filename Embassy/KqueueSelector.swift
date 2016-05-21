//
//  KqueueSelector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

class KqueueSelector: SelectorType {
    enum Error: ErrorType {
        case KeyError(fileDescriptor: Int32)
        case KqueueError(number: Int, message: String)
        /// Return a kqueue error with the last error number and description
        static func lastKqueueError() -> Error {
            return .KqueueError(number: Int(errno), message: lastErrorDescription())
        }
        /// Return description for last error
        static func lastErrorDescription() -> String {
            return String.fromCString(UnsafePointer(strerror(errno))) ?? "Unknown Error: \(errno)"
        }
    }
    
    // the maximum event number to select from kqueue at once (one kevent call)
    private let selectMaximumEvent: Int
    private let kqueue: Int32
    private var fileDescriptorMap: [Int32: SelectorKey] = [:]
    
    init(selectMaximumEvent: Int = 1024) throws {
        kqueue = Darwin.kqueue()
        guard kqueue >= 0 else {
            throw Error.lastKqueueError()
        }
        self.selectMaximumEvent = selectMaximumEvent
    }
    
    deinit {
        close()
    }
    
    func register(fileDescriptor: Int32, events: Set<IOEvent>, data: AnyObject?) throws -> SelectorKey {
        // ensure the file descriptor doesn't exist already
        guard fileDescriptorMap[fileDescriptor] != nil else {
            throw Error.KeyError(fileDescriptor: fileDescriptor)
        }
        let key = SelectorKey(fileDescriptor: fileDescriptor, events: events, data: data)
        fileDescriptorMap[fileDescriptor] = key
        
        var kevents: [Darwin.kevent] = []
        for event in events {
            let filter: Int16
            switch event {
            case .Read:
                filter = Int16(EVFILT_READ)
            case .Write:
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

        // Notice: we need to get the event count before we go into
        // `withUnsafeMutableBufferPointer`, as we cannot rely on it inside the closure
        // (you can read the offical document)
        let keventCount = kevents.count
        guard kevents.withUnsafeMutableBufferPointer({ pointer in
            Darwin.kevent(kqueue, pointer.baseAddress, Int32(keventCount), nil, Int32(0), nil) >= 0
        }) else {
            throw Error.lastKqueueError()
        }
        return key
    }
    
    func unregister(fileDescriptor: Int32) throws -> SelectorKey {
        // ensure the file descriptor exists
        guard let key = fileDescriptorMap[fileDescriptor] else {
            throw Error.KeyError(fileDescriptor: fileDescriptor)
        }
        fileDescriptorMap.removeValueForKey(fileDescriptor)
        // TODO: remove the event filters from the kqueue
        return key
    }
    
    func close() {
        // TODO:
    }
    
    func select(timeout: NSTimeInterval?) throws -> [(key: SelectorKey, events: Set<IOEvent>)] {
        var timeSpec: timespec?
        if let timeout = timeout {
            if timeout > 0 {
                var integer = 0.0
                let nsec = Int(modf(timeout, &integer) * Double(NSEC_PER_SEC))
                timeSpec = timespec(tv_sec: Int(timeout), tv_nsec: nsec)
            } else {
                // TODO:
            }
        }
        
        let timeSpecPointer: UnsafePointer<timespec>
        if timeSpec != nil {
            timeSpecPointer = withUnsafePointer(&timeSpec!) { $0 }
        } else {
            timeSpecPointer = nil
        }
        
        var kevents = Array<Darwin.kevent>(count: selectMaximumEvent, repeatedValue: Darwin.kevent())
        let eventCount = kevents.withUnsafeMutableBufferPointer { pointer in
             return Darwin.kevent(kqueue, nil, 0, pointer.baseAddress, Int32(selectMaximumEvent), timeSpecPointer)
        }
        guard eventCount >= 0 else {
            throw Error.lastKqueueError()
        }
        
        for index in 0..<Int(eventCount) {
            let event = kevents[index]
            // TODO: handle the event here
        }
        
        // TODO:
        return []
    }
    
    subscript(fileDescriptor: Int32) -> SelectorKey? {
        get {
            return fileDescriptorMap[fileDescriptor]
        }
    }
}
