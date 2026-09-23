//
//  TestingHelpers.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

/// Base unit for sequencing events in tests. Loopback IO completes in well
/// under a millisecond, so steps only need to be far enough apart to order
/// events deterministically, not to wait for anything real.
let tick: TimeInterval = 0.1

/// Timing slack for duration assertions, in seconds. kqueue timeouts and GCD
/// deadlines are accurate to a few milliseconds.
let tickAccuracy: TimeInterval = 0.05

/// Mutable state shared between the test and callbacks that run on the event
/// loop thread or a helper thread. Swift 6 rejects mutating a captured `var`
/// from a `@Sendable` closure; this box is the sanctioned way to do it.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        get { withLock { $0 } }
        set { withLock { $0 = newValue } }
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&storage)
    }
}

extension Locked where Value: RangeReplaceableCollection {
    func append(_ element: Value.Element) {
        withLock { $0.append(element) }
    }
}

/// Runs blocking work (accept, select, runForever) on its own thread and
/// suspends until it finishes, so no cooperative-pool thread is tied up.
func onThread<Value: Sendable>(
    _ work: @escaping @Sendable () throws -> Value
) async throws -> Value {
    try await withCheckedThrowingContinuation { continuation in
        Thread.detachNewThread {
            continuation.resume(with: Result { try work() })
        }
    }
}

/// Like `onThread`, also returning how long the work took in seconds.
func timed<Value: Sendable>(
    _ work: @escaping @Sendable () throws -> Value
) async throws -> (result: Value, elapsed: TimeInterval) {
    let start = DispatchTime.now()
    let result = try await onThread(work)
    return (result, seconds(since: start))
}

/// Runs the loop on its own thread until something calls `stop()`, and returns
/// how long that took in seconds.
@discardableResult
func run(_ loop: SelectorEventLoop) async -> TimeInterval {
    let start = DispatchTime.now()
    await withCheckedContinuation { continuation in
        Thread.detachNewThread {
            loop.runForever()
            continuation.resume()
        }
    }
    return seconds(since: start)
}

func seconds(since start: DispatchTime) -> TimeInterval {
    TimeInterval(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / TimeInterval(NSEC_PER_SEC)
}

/// Schedules `work` on a background queue `ticks` ticks from now
func after(_ ticks: Double, _ work: @escaping @Sendable () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + ticks * tick, execute: work)
}

/// Asserts `elapsed` is within `tickAccuracy` of `expected` seconds
func expectDuration(
    _ expected: TimeInterval,
    _ elapsed: TimeInterval,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        abs(elapsed - expected) <= tickAccuracy,
        "expected ~\(expected)s, took \(elapsed)s",
        sourceLocation: sourceLocation
    )
}

/// A listening socket on `::1` bound to a kernel-assigned port. Binding port 0
/// instead of probing for a free port first means parallel tests cannot race
/// each other for the same port.
func makeListenSocket(blocking: Bool = false) throws -> (socket: TCPSocket, port: Int) {
    let socket = try TCPSocket(blocking: blocking)
    try socket.bind(port: 0, interface: "::1")
    try socket.listen()
    return (socket, try socket.getSockName().1)
}

func makeRandomString(_ length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}

func utf8String(_ data: Data) -> String {
    String(decoding: data, as: UTF8.self)
}

struct FileDescriptorEvent: Hashable, Sendable {
    let fileDescriptor: Int32
    let ioEvent: IOEvent
}

/// A Sendable summary of a select() result: (file descriptor, events) per key
struct ReadyDescriptor: Hashable, Sendable {
    let fileDescriptor: Int32
    let events: IOEvent
    let hasData: Bool
}

func summarize(_ events: [(SelectorKey, IOEvent)]) -> [ReadyDescriptor] {
    events.map { ReadyDescriptor(fileDescriptor: $0.0.fileDescriptor, events: $0.1, hasData: $0.0.data != nil) }
}

func toEventSet(_ events: [(SelectorKey, IOEvent)]) -> Set<FileDescriptorEvent> {
    Set(events.flatMap { key, ioEvents in
        ioEvents.elements.map { FileDescriptorEvent(fileDescriptor: key.fileDescriptor, ioEvent: $0) }
    })
}
