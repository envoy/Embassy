//
//  IOEventHub.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// IOEventHub uses given selector to monitor IO events in a
/// background thread, then trigger callbacks in the desired queue on
public final class IOEventHub {
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
        
        try selector.register(pipeReceiver, events: [.Read], data: nil)
        thread = NSThread(target: self, selector: #selector(runLoop), object: nil)
    }
    
    deinit {
        stop()
        // TODO: join thread?
        close(pipeSender)
        close(pipeReceiver)
    }

    func subscribe(fileDescriptor: Int32, events: Set<IOEvent>, queue: dispatch_queue_t, callback: (events: Set<IOEvent>) -> Void) {
        // TODO: subscribe it here
        try! interruptSelector()
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
