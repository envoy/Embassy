//
//  DefaultHTTPServer.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Dispatch

/// Thread confinement: every method and stored property of this type belongs to the thread
/// running its `EventLoop`. The `Sendable` conformance is unchecked because references to it are
/// captured by `@Sendable` loop callbacks, not because it is safe to touch from other threads.
public final class DefaultHTTPServer: HTTPServer, @unchecked Sendable {
    public let logger = DefaultLogger()
    public let app: SWSGI

    /// Interface of TCP/IP to bind
    public let interface: String
    /// Port of TCP/IP to bind
    public let port: Int

    // the socket for accepting incoming connections
    // nil until start() succeeds; stop() resets it so the server can be started again
    private var acceptSocket: TCPSocket?
    private let eventLoop: EventLoop
    private var connections = Set<HTTPConnection>()

    public init(
        eventLoop: EventLoop,
        interface: String = "::1",
        port: Int = 0,
        app: @escaping SWSGI
    ) {
        self.eventLoop = eventLoop
        self.app = app
        self.interface = interface
        self.port = port
    }

    deinit {
        stop()
    }

    public var listenAddress: (host: String, port: Int) {
        guard let acceptSocket else {
            preconditionFailure("listenAddress read before start()")
        }
        return try! acceptSocket.getSockName()
    }

    public func start() throws {
        guard acceptSocket == nil else {
            logger.error("Server already started")
            return
        }
        logger.info("Starting HTTP server on [\(interface)]:\(port) ...")
        let socket = try TCPSocket()
        try socket.bind(port: port, interface: interface)
        try socket.listen()
        eventLoop.setReader(socket.fileDescriptor) { [unowned self] in
            self.handleNewConnection()
        }
        acceptSocket = socket
        logger.info("HTTP server running")
    }

    public func stop() {
        guard let socket = acceptSocket else {
            logger.error("Server not started")
            return
        }
        eventLoop.removeReader(socket.fileDescriptor)
        socket.close()
        acceptSocket = nil
        for connection in connections {
            connection.close()
        }
        connections = []
        logger.info("HTTP server stopped")
    }

    public func stopAndWait() {
        let semaphore = DispatchSemaphore(value: 0)
        eventLoop.call {
            self.stop()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }

    public func stopAndWait() async {
        await withCheckedContinuation { continuation in
            eventLoop.call {
                self.stop()
                continuation.resume()
            }
        }
    }

    // called to handle new connections
    private func handleNewConnection() {
        guard let acceptSocket else {
            return
        }
        do {
            let clientSocket = try acceptSocket.accept()
            let (address, port) = try clientSocket.getPeerName()
            let transport = Transport(socket: clientSocket, eventLoop: eventLoop)
            let connection = HTTPConnection(
                app: appForConnection,
                serverName: "[\(interface)]",
                serverPort: self.port,
                transport: transport,
                eventLoop: eventLoop,
                logger: logger
            )
            connections.insert(connection)
            connection.closedCallback = { [unowned self, unowned connection] in
                self.connections.remove(connection)
            }
            logger.info("New connection \(connection.uuid) from [\(address)]:\(port)")
        } catch {
            logger.error("error handling connection: \(error)")
        }
    }

    private func appForConnection(
        _ environ: [String: Any],
        startResponse: @escaping SWSGIStartResponse,
        sendBody: @escaping SWSGISendBody
    ) {
        app(environ, startResponse, sendBody)
    }

}
