//
//  EventLoopType.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// EventLoop uses given selector to monitor IO events, trigger callbacks when needed to
/// Follow Python EventLoop design https://docs.python.org/3/library/asyncio-eventloop.html
public protocol EventLoopType {
    /// Indicate whether is this event loop running
    var running: Bool { get }
    
    /// Set a read-ready callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    ///  - Parameter callback: callback function to be triggered when file is ready to be read
    func setReader(fileDescriptor: Int32, callback: Void -> Void)

    /// Remove reader callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    func removeReader(fileDescriptor: Int32)
    
    /// Set a write-ready callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    ///  - Parameter callback: callback function to be triggered when file is ready to be written
    func setWriter(fileDescriptor: Int32, callback: Void -> Void)

    /// Remove writer callback for given fileDescriptor
    ///  - Parameter fileDescriptor: target file descriptor
    func removeWriter(fileDescriptor: Int32)
    
    /// Call given callback as soon as possible (the next event loop iteration)
    ///  - Parameter callback: the callback function to be called
    func callSoon(callback: Void -> Void)
    
    /// Call given callback `delay` seconds later
    ///  - Parameter delay: delaying in seconds
    ///  - Parameter callback: the callback function to be called
    func callLater(delay: NSTimeInterval, callback: Void -> Void)
    
    /// Call given callback at specific time
    ///  - Parameter time: time the callback to be called
    ///  - Parameter callback: the callback function to be called
    func callAt(time: NSDate, callback: Void -> Void)

    /// Stop the event loop
    func stop()

    /// Run the event loop forever
    func runForever()
}