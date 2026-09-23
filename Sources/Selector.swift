//
//  Selector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Set of IO readiness events. An OptionSet rather than Set<enum>: it is a single byte,
/// hashes trivially, and never allocates.
public struct IOEvent: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// File descriptor is ready to be read
    public static let read = IOEvent(rawValue: 1 << 0)
    /// File descriptor is ready to be written
    public static let write = IOEvent(rawValue: 1 << 1)

    /// The individual events contained in this set, in read-then-write order
    public var elements: [IOEvent] {
        [IOEvent.read, IOEvent.write].filter(contains)
    }
}

/// Represent a subscription for a file descriptor in Selector
public struct SelectorKey {
    /// File descriptor
    let fileDescriptor: Int32
    /// Events to monitor
    let events: IOEvent
    /// User custom data to be returned when we see an IO event
    let data: Any?
}

/// Selector provides a way to poll lots of file descriptors for IO events in an efficient way.
/// The basic interface design follows https://docs.python.org/3/library/selectors.html
public protocol Selector {
    /// Register a file descriptor for given IO events to watch
    ///  - Parameter fileDescriptor: the file descriptor to watch
    ///  - Parameter events: IO events to watch
    ///  - Parameter data: user custom data to be returned when we see an IO event
    ///  - Returns: added SelectorKey
    @discardableResult
    func register(_ fileDescriptor: Int32, events: IOEvent, data: Any?) throws -> SelectorKey

    /// Unregister a file descriptor from selector
    @discardableResult
    func unregister(_ fileDescriptor: Int32) throws -> SelectorKey

    /// Close the selector to release underlaying resource
    func close()

    /// Select to see if the registered file descriptors have IO events, wait until
    /// we see a file descriptor ready or timeout
    ///  - Parameter timeout: how long time to wait until return empty list,
    ///                       if timeout <= 0, it won't block but returns current file descriptor status immediately,
    ///                       if timeout == nil, it will block until there is a file descriptor ready
    ///  - Returns: an array of (key, events) for ready file descriptors
    func select(timeout: TimeInterval?) throws -> [(SelectorKey, IOEvent)]

    /// Return the SelectorKey for given file descriptor
    subscript(fileDescriptor: Int32) -> SelectorKey? { get }
}
