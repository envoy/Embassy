//
//  HTTPServer.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public final class HTTPServer: HTTPServerType {
    let logger = Logger()
    public var app: SWSGI
    
    /// Interface of TCP/IP to bind
    let interface: String
    /// Port of TCP/IP to bind
    let port: Int
    
    // the socket for accepting incoming connections
    private var acceptSocket: TCPSocket!
    private var acceptTransport: Transport!
    private let eventLoop: EventLoop
    private var connections = Set<HTTPConnection>()
    
    init(eventLoop: EventLoop, app: SWSGI, interface: String = "::1", port: Int = 8080) {
        self.eventLoop = eventLoop
        self.app = app
        self.interface = interface
        self.port = port
    }
    
    public func start() throws {
        guard acceptSocket == nil else {
            logger.error("Server already started")
            return
        }
        logger.info("Starting HTTP server on [\(interface)]:\(port) ...")
        acceptSocket = try TCPSocket()
        try acceptSocket.bind(port, interface: interface)
        try acceptSocket.listen()
        eventLoop.setReader(acceptSocket.fileDescriptor) { [unowned self] in
            self.handleNewConnection()
        }
        logger.info("HTTP server running")
    }
    
    public func stop() {
        acceptTransport.close()
        for connection in connections {
            connection.close()
        }
        connections = []
        logger.info("HTTP server stopped")
    }
    
    // called to handle new connections
    private func handleNewConnection() {
        let clientSocket = try! acceptSocket.accept()
        let (address, port) = try! clientSocket.getPeerName()
        logger.info("New connection from [\(address)]:\(port)")
        let transport = Transport(socket: clientSocket, eventLoop: eventLoop)
        let connection = HTTPConnection(
            app: appForConnection,
            serverName: "[\(interface)]",
            serverPort: self.port,
            transport: transport,
            eventLoop: eventLoop
        )
        connections.insert(connection)
        connection.closedCallback = { [unowned self] in
            self.connections.remove(connection)
        }
    }
    
    private func appForConnection(environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) {
        app(environ: environ, startResponse: startResponse, sendBody: sendBody)
    }
    
}
