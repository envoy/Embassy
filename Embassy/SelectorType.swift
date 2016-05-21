//
//  SelectorType.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Event of IO
enum IOEvent {
    case Read
    case Write
}

/// Represent a subscription for a file descriptor in Selector
struct SelectorKey {
    /// File descriptor
    let fileDescriptor: Int32
    /// Events to monitor
    let events: Set<IOEvent>
    /// User custom data to be returned when we see an IO event
    let data: AnyObject?
}

/// Selector provides a way to poll lots of file descriptors for IO events in an efficient way.
/// The basic interface design follows https://docs.python.org/3/library/selectors.html
protocol SelectorType {
    /// Register a file descriptor for given IO events to watch
    ///  - Parameter fileDescriptor: the file descriptor to watch
    ///  - Parameter events: IO events to watch
    ///  - Parameter data: user custom data to be returned when we see an IO event
    func register(fileDescriptor: Int32, events: Set<IOEvent>, data: AnyObject?) throws -> SelectorKey
    
    /// Unregister a file descriptor from selector
    func unregister(fileDescriptor: Int32) throws -> SelectorKey
    
    /// Close the selector to release underlaying resource
    func close()
    
    /// Select to see if the registered file descriptors have IO events, wait until
    /// we see a file descriptor ready or timeout
    ///  - Parameter timeout: how long time to wait until return empty list,
    ///                       if timeout <= 0, it won't block but returns current file descriptor status immediately,
    ///                       if timeout == nil, it will block until there is a file descriptor ready
    ///  - Returns: an array of (key, events) for ready file descriptors
    func select(timeout: NSTimeInterval?) -> [(key: SelectorKey, events: Set<IOEvent>)]
    
    /// Return the SelectorKey for given file descriptor
    subscript(fileDescriptor: Int32) throws -> SelectorKey? { get }
}
