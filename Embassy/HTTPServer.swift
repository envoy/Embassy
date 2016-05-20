//
//  HTTPServer.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

class HTTPServer: HTTPServerType {
    var app: SWSGI
    
    /// Interface of TCP/IP to bind
    let interface: String
    /// Port of TCP/IP to bind
    let port: Int
    
    // the socket for accepting incoming connections
    private var acceptSocket: TCPSocket!
    
    init(app: SWSGI, interface: String = "::1", port: Int = 8080) {
        self.app = app
        self.interface = interface
        self.port = port
    }
    
    func start(ready: Void -> Void) throws {
        acceptSocket = try! TCPSocket()
        try acceptSocket.bind(port, interface: interface)
    }
    
    func stop(stopped: Void -> Void) {
        
    }
}
