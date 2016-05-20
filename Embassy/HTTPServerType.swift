//
//  HTTPServerType.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// HTTPServerType is the protocol for basic SWSGI server
public protocol HTTPServerType {
    /// The SWSGI app to serve
    var app: SWSGI { get set }
    /// Start the HTTP server
    ///  - Parameter ready: the callback to be called when the server is ready to serve
    func start(ready: Void -> Void) throws
    /// Stop the HTTP server
    ///  - Parameter stopped: the callback to be called when the server is stopped
    func stop(stopped: Void -> Void)
}
