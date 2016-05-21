//
//  EventLoop.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation


private class CallbackHandle {
    let reader: (Void -> Void)?
    let writer: (Void -> Void)?
    init(reader: (Void -> Void)? = nil, writer: (Void -> Void)? = nil) {
        self.reader = reader
        self.writer = writer
    }
}

/// EventLoop uses given selector to monitor IO events, trigger callbacks when needed to
/// Follow Python EventLoop design https://docs.python.org/3/library/asyncio-eventloop.html
public final class EventLoop {
    private var thread: NSThread!
    private let selector: SelectorType
    // these are for self-pipe-trick ref: https://cr.yp.to/docs/selfpipe.html
    // to be able to interrupt the blocking selector, we create a pipe and add it to the
    // selector, whenever we want to interrupt the selector, we send a byte
    private let pipeSender: Int32
    private let pipeReceiver: Int32
    private var running: Bool = true
    
    init(selector: SelectorType) throws {
        self.selector = selector
        
        var pipeFds = [Int32](count: 2, repeatedValue: 0)
        let pipeResult = pipeFds.withUnsafeMutableBufferPointer { pipe($0.baseAddress) }
        guard pipeResult >= 0 else {
            throw OSError.lastIOError()
        }
        pipeSender = pipeFds[0]
        pipeReceiver = pipeFds[1]
        
        thread = NSThread(target: self, selector: #selector(runLoop), object: nil)
    }
    
    deinit {
        stop()
        // TODO: join thread?
        close(pipeSender)
        close(pipeReceiver)
    }

    /// Set a read-ready callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    ///  - Parameter callback: callback function to be triggered when file is ready to be read
    func setReader(fileDescriptor: Int32, callback: Void -> Void) {
        // we already have the file descriptor in selector, unregister it then register
        if let key = selector[fileDescriptor] {
            let oldHandle = key.data as! CallbackHandle
            let handle = CallbackHandle(reader: callback, writer: oldHandle.writer)
            try! selector.unregister(fileDescriptor)
            try! selector.register(fileDescriptor, events: key.events.union([.Read]), data: handle)
        // register the new file descriptor
        } else {
            try! selector.register(fileDescriptor, events: [.Read], data: CallbackHandle(reader: callback))
        }
    }
    
    /// Remove reader callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    func removeReader(fileDescriptor: Int32) {
        guard let key = selector[fileDescriptor] else {
            return
        }
        try! selector.unregister(fileDescriptor)
        let newEvents = key.events.subtract([.Read])
        guard !newEvents.isEmpty else {
            return
        }
        let oldHandle = key.data as! CallbackHandle
        let handle = CallbackHandle(reader: nil, writer: oldHandle.writer)
        try! selector.register(fileDescriptor, events: newEvents, data: handle)
    }
    
    /// Set a write-ready callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    ///  - Parameter callback: callback function to be triggered when file is ready to be written
    func setWriter(fileDescriptor: Int32, callback: Void -> Void) {
        // we already have the file descriptor in selector, unregister it then register
        if let key = selector[fileDescriptor] {
            let oldHandle = key.data as! CallbackHandle
            let handle = CallbackHandle(reader: oldHandle.reader, writer: callback)
            try! selector.unregister(fileDescriptor)
            try! selector.register(fileDescriptor, events: key.events.union([.Write]), data: handle)
            // register the new file descriptor
        } else {
            try! selector.register(fileDescriptor, events: [.Write], data: CallbackHandle(writer: callback))
        }
    }
    
    /// Remove writer callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    func removeWriter(fileDescriptor: Int32) {
        guard let key = selector[fileDescriptor] else {
            return
        }
        try! selector.unregister(fileDescriptor)
        let newEvents = key.events.subtract([.Write])
        guard !newEvents.isEmpty else {
            return
        }
        let oldHandle = key.data as! CallbackHandle
        let handle = CallbackHandle(reader: oldHandle.reader, writer: nil)
        try! selector.register(fileDescriptor, events: newEvents, data: handle)
    }
    
    func stop() {
        running = false
        try! interruptSelector()
    }
    
    // interrupt the selector
    private func interruptSelector() throws {
        let byte = [UInt8](count: 1, repeatedValue: 0)
        guard send(pipeSender, byte, byte.count, 0) >= 0 else {
            throw OSError.lastIOError()
        }
    }
    
    // Run once iteration for the event loop
    private func runOnce() {
    }
    
    @objc private func runLoop() {
        while running {
            let events = try! selector.select(nil)
            for (key, ioEvents) in events {
                // skip pipe receiver interrupting event
                guard key.fileDescriptor != pipeReceiver else {
                    continue
                }
                // TODO: handle the event here
            }
        }
    }
    
}
