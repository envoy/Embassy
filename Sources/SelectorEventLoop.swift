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
    // callbacks scheduled to be called later, as a min-heap on a monotonic deadline.
    // DispatchTime is mach_absolute_time underneath, so wall-clock changes cannot fire or
    // starve timers; ContinuousClock would be the modern spelling but needs iOS 16.
    private var scheduledCallbacks = Atomic<[(DispatchTime, @Sendable () -> Void)]>([])
    // fixed anchor mapping wall-clock `Date`s onto the monotonic timeline, taken once at init so
    // `call(atTime:)` targets keep their relative order regardless of when they are scheduled
    private let anchorDate = Date()
    private let anchorTime = DispatchTime.now()

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
        schedule(at: .now() + max(0, delay), callback: callback)
    }

    public func call(atTime time: Date, callback: @escaping @Sendable () -> Void) {
        // map the wall-clock target onto the monotonic timeline via the init-time anchor.
        // A wall-clock jump after init shifts `atTime` targets by the jump; `withDelay` is
        // unaffected, and is what timers should normally use.
        schedule(at: anchorTime + max(0, time.timeIntervalSince(anchorDate)), callback: callback)
    }

    private func schedule(at deadline: DispatchTime, callback: @escaping @Sendable () -> Void) {
        scheduledCallbacks.withLock { callbacks in
            HeapSort.heapPush(&callbacks, item: (deadline, callback)) { $0.0 < $1.0 }
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

    /// Seconds from now until `deadline`, clamped at zero
    private static func seconds(until deadline: DispatchTime) -> TimeInterval {
        let now = DispatchTime.now().uptimeNanoseconds
        guard deadline.uptimeNanoseconds > now else { return 0 }
        return TimeInterval(deadline.uptimeNanoseconds - now) / TimeInterval(NSEC_PER_SEC)
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
        // as the scheduledCallbacks is a heap queue, the first one is the earliest deadline;
        // block in select only until then (nil means no timers, block until IO)
        let timeout: TimeInterval? = scheduledCallbacks.withValue { callbacks in
            callbacks.first.map { SelectorEventLoop.seconds(until: $0.0) }
        }

        var events: [(SelectorKey, IOEvent)] = []
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
            if ioEvents.contains(.read), let callback = handle.reader {
                callback()
            }
            if ioEvents.contains(.write), let callback = handle.writer {
                callback()
            }
        }

        // Call scheduled callbacks
        let now = DispatchTime.now()
        var readyScheduledCallbacks: [@Sendable () -> Void] = []
        scheduledCallbacks.withLock { callbacks in
            // keep popping expired callbacks
            while let first = callbacks.first, first.0 <= now {
                // pop the expired callbacks from heap queue and add them to ready callback list
                let (_, callback) = HeapSort.heapPop(&callbacks) { $0.0 < $1.0 }
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
