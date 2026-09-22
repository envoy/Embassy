//
//  SelectorEventLoop.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

private class CallbackHandle {
    let reader: (@Sendable () -> Void)?
    let writer: (@Sendable () -> Void)?
    init(reader: (@Sendable () -> Void)? = nil, writer: (@Sendable () -> Void)? = nil) {
        self.reader = reader
        self.writer = writer
    }
}

/// EventLoop uses given selector to monitor IO events, trigger callbacks when needed to
/// Follow Python EventLoop design https://docs.python.org/3/library/asyncio-eventloop.html
///
/// Thread contract: `call(...)` and `stop()` are safe from any thread. Everything else, including
/// `setReader`/`setWriter`, must run on the thread executing `runForever()`. `Sendable` is unchecked
/// because the loop is captured by its own `@Sendable` callbacks; the cross-thread entry points are
/// guarded by `Atomic`.
public final class SelectorEventLoop: EventLoop, @unchecked Sendable {
    private let isRunning = Atomic<Bool>(false)
    /// Indicate whether is this event loop running (readable from any thread)
    public var running: Bool { isRunning.value }
    private let selector: Selector
    // these are for self-pipe-trick ref: https://cr.yp.to/docs/selfpipe.html
    // to be able to interrupt the blocking selector, we create a pipe and add it to the
    // selector, whenever we want to interrupt the selector, we send a byte
    private let pipeSender: Int32
    private let pipeReceiver: Int32
    // callbacks ready to be called at the next iteration
    private var readyCallbacks = Atomic<[@Sendable () -> Void]>([])
    // callbacks scheduled to be called later
    private var scheduledCallbacks = Atomic<[(Date, @Sendable () -> Void)]>([])

    public init(selector: Selector) throws {
        self.selector = selector
        var pipeFds = [Int32](repeating: 0, count: 2)
        let pipeResult = pipeFds.withUnsafeMutableBufferPointer {
            Darwin.pipe($0.baseAddress)
        }
        guard pipeResult >= 0 else {
            throw OSError.lastIOError()
        }
        pipeReceiver = pipeFds[0]
        pipeSender = pipeFds[1]
        IOUtils.setBlocking(fileDescriptor: pipeSender, blocking: false)
        IOUtils.setBlocking(fileDescriptor: pipeReceiver, blocking: false)
        // subscribe to pipe receiver read-ready event, do nothing, just allow selector
        // to be interrupted

        // Notice: we use a local copy of pipeReceiver to avoid referencing self
        // here, thus we won't have reference cycle problem
        let localPipeReceiver = pipeReceiver
        setReader(pipeReceiver) {
            // consume the pipe receiver, so that it won't keep triggering read event
            let size = PIPE_BUF
            var bytes = Data(count: Int(size))
            var readSize = 1
            while readSize > 0 {
                readSize = bytes.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
                    Darwin.read(localPipeReceiver, buffer.baseAddress, buffer.count)
                }
            }
        }
    }

    deinit {
        stop()
        removeReader(pipeReceiver)
        _ = Darwin.close(pipeSender)
        _ = Darwin.close(pipeReceiver)
    }

    public func setReader(_ fileDescriptor: Int32, callback: @escaping @Sendable () -> Void) {
        // we already have the file descriptor in selector, unregister it then register
        if let key = selector[fileDescriptor] {
            let oldHandle = key.data as! CallbackHandle
            let handle = CallbackHandle(reader: callback, writer: oldHandle.writer)
            try! selector.unregister(fileDescriptor)
            try! selector.register(
                fileDescriptor,
                events: key.events.union([.read]),
                data: handle
            )
        // register the new file descriptor
        } else {
            try! selector.register(
                fileDescriptor,
                events: [.read],
                data: CallbackHandle(reader: callback)
            )
        }
    }

    public func removeReader(_ fileDescriptor: Int32) {
        guard let key = selector[fileDescriptor] else {
            return
        }
        try! selector.unregister(fileDescriptor)
        let newEvents = key.events.subtracting([.read])
        guard !newEvents.isEmpty else {
            return
        }
        let oldHandle = key.data as! CallbackHandle
        let handle = CallbackHandle(reader: nil, writer: oldHandle.writer)
        try! selector.register(fileDescriptor, events: newEvents, data: handle)
    }

    public func setWriter(_ fileDescriptor: Int32, callback: @escaping @Sendable () -> Void) {
        // we already have the file descriptor in selector, unregister it then register
        if let key = selector[fileDescriptor] {
            let oldHandle = key.data as! CallbackHandle
            let handle = CallbackHandle(reader: oldHandle.reader, writer: callback)
            try! selector.unregister(fileDescriptor)
            try! selector.register(
                fileDescriptor,
                events: key.events.union([.write]),
                data: handle
            )
            // register the new file descriptor
        } else {
            try! selector.register(
                fileDescriptor,
                events: [.write],
                data: CallbackHandle(writer: callback)
            )
        }
    }

    public func removeWriter(_ fileDescriptor: Int32) {
        guard let key = selector[fileDescriptor] else {
            return
        }
        try! selector.unregister(fileDescriptor)
        let newEvents = key.events.subtracting([.write])
        guard !newEvents.isEmpty else {
            return
        }
        let oldHandle = key.data as! CallbackHandle
        let handle = CallbackHandle(reader: oldHandle.reader, writer: nil)
        try! selector.register(fileDescriptor, events: newEvents, data: handle)
    }

    public func call(callback: @escaping @Sendable () -> Void) {
        readyCallbacks.withLock { callbacks in
            callbacks.append(callback)
        }
        interruptSelector()
    }

    public func call(withDelay delay: TimeInterval, callback: @escaping @Sendable () -> Void) {
        call(atTime: Date().addingTimeInterval(delay), callback: callback)
    }

    public func call(atTime time: Date, callback: @escaping @Sendable () -> Void) {
        scheduledCallbacks.withLock { callbacks in
            HeapSort.heapPush(&callbacks, item: (time, callback)) {
                $0.0.timeIntervalSince1970 < $1.0.timeIntervalSince1970
            }
        }
        interruptSelector()
    }

    public func stop() {
        isRunning.value = false
        interruptSelector()
    }

    public func runForever() {
        isRunning.value = true
        while running {
            runOnce()
        }
    }

    // interrupt the selector
    private func interruptSelector() {
        let byte = [UInt8](repeating: 0, count: 1)
        let rc = write(pipeSender, byte, byte.count)
        assert(
            rc >= 0,
            "Failed to interrupt selector, errno=\(errno), message=\(lastErrorDescription())"
        )
    }

    // Run once iteration for the event loop
    private func runOnce() {
        var timeout: TimeInterval?
        scheduledCallbacks.withValue { callbacks in
            // as the scheduledCallbacks is a heap queue, the first one will be the smallest one
            // (the latest one)
            if let firstTuple = callbacks.first {
                // schedule timeout for the very next scheduled callback
                let (minTime, _) = firstTuple
                timeout = max(0, minTime.timeIntervalSince(Date()))
            } else {
                timeout = nil
            }
        }

        var events: [(SelectorKey, Set<IOEvent>)] = []
        // Poll IO events
        do {
            events = try selector.select(timeout: timeout)
        } catch OSError.ioError(let number, let message) {
            assert(number == EINTR, "Failed to call selector, errno=\(number), message=\(message)")
        } catch {
            fatalError("Failed to call selector, errno=\(errno), message=\(lastErrorDescription())")
        }
        for (key, ioEvents) in events {
            guard let handle = key.data as? CallbackHandle else {
                continue
            }
            for ioEvent in ioEvents {
                switch ioEvent {
                case .read:
                    if let callback = handle.reader {
                        callback()
                    }
                case .write:
                    if let callback = handle.writer {
                        callback()
                    }
                }
            }
        }

        // Call scheduled callbacks
        let now = Date()
        var readyScheduledCallbacks: [@Sendable () -> Void] = []
        scheduledCallbacks.withLock { callbacks in
            // keep poping expired callbacks
            let timestamp = now.timeIntervalSince1970
            while let first = callbacks.first, timestamp >= first.0.timeIntervalSince1970 {
                // pop the expired callbacks from heap queue and add them to ready callback list
                let (_, callback) = HeapSort.heapPop(&callbacks) {
                    $0.0.timeIntervalSince1970 < $1.0.timeIntervalSince1970
                }
                readyScheduledCallbacks.append(callback)
            }
        }

        // Call ready callbacks; take the queue in one swap so callbacks that
        // enqueue more work run on the next iteration rather than starving IO
        var callbacks = readyCallbacks.swap(newValue: [])
        callbacks.append(contentsOf: readyScheduledCallbacks)
        for callback in callbacks {
            callback()
        }
    }

}
