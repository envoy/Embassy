//
//  HTTPConnection.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// HTTPConnection represents an active HTTP connection
/// Thread confinement: every method and stored property of this type belongs to the thread
/// running its `EventLoop`. The `Sendable` conformance is unchecked because references to it are
/// captured by `@Sendable` loop callbacks, not because it is safe to touch from other threads.
public final class HTTPConnection: @unchecked Sendable {
    enum RequestState {
        case parsingHeader
        case readingBody
    }

    enum ResponseState {
        case sendingHeader
        case sendingBody
    }

    public let logger = DefaultLogger()
    public let uuid: String = UUID().uuidString
    public let transport: Transport
    public let app: SWSGI
    public let serverName: String
    public let serverPort: Int
    /// Callback to be called when this connection closed
    var closedCallback: (() -> Void)?

    private(set) var requestState: RequestState = .parsingHeader
    private(set) var responseState: ResponseState = .sendingHeader
    public let eventLoop: EventLoop
    private lazy var headerParser = HTTPHeaderParser()
    private var headerElements: [HTTPHeaderParser.Element] = []
    private var initialBody: Data?
    private var inputHandler: ((Data) -> Void)?
    // total content length to read
    private var contentLength: Int?
    // total data bytes we've already read
    private var readDataLength: Int = 0

    public init(
        app: @escaping SWSGI,
        serverName: String,
        serverPort: Int,
        transport: Transport,
        eventLoop: EventLoop,
        logger: Logger,
        closedCallback: (() -> Void)? = nil
    ) {
        self.app = app
        self.serverName = serverName
        self.serverPort = serverPort
        self.transport = transport
        self.eventLoop = eventLoop
        self.closedCallback = closedCallback

        transport.readDataCallback = { [unowned self] data in
            self.handleDataReceived(data)
        }
        transport.closedCallback = { [unowned self] reason in
            self.handleConnectionClosed(reason)
        }

        let propagateHandler = PropagateLogHandler(logger: logger)
        let contextHandler = TransformLogHandler(
            handler: propagateHandler
        ) { [unowned self] record in
            record.overwriteMessage { [unowned self] in "[\(self.uuid)] \($0.message)" }
        }
        self.logger.add(handler: contextHandler)
    }

    public func close() {
        transport.close()
    }

    // called to handle data received
    private func handleDataReceived(_ data: Data) {
        switch requestState {
        case .parsingHeader:
            handleHeaderData(data)
        case .readingBody:
            handleBodyData(data)
        }
    }

    // called to handle header data
    private func handleHeaderData(_ data: Data) {
        headerElements += headerParser.feed(data)
        // we only handle when there are elements in header parser
        guard let lastElement = headerElements.last else {
            return
        }
        // we only handle the it when we get the end of header
        guard case .end = lastElement else {
            return
        }

        guard case .head(let method, let path, let version)? = headerElements.first else {
            // the parser always emits .head first; anything else is a malformed request
            logger.error("Header parsed without a request line, closing connection")
            transport.close()
            return
        }
        var headers: [(String, String)] = []
        headers.reserveCapacity(headerElements.count)
        for element in headerElements {
            switch element {
            case .head:
                break
            case .header(let key, let value):
                headers.append((key, value))
            case .end(let bodyPart):
                initialBody = bodyPart
            }
        }
        logger.info(
            "Header parsed, method=\(method), path=\(path.debugDescription), " +
            "version=\(version.debugDescription), headers=\(headers)"
        )
        let request = HTTPRequest(
            method: HTTPRequest.Method.fromString(method),
            path: path,
            version: version,
            headers: headers
        )
        var environ = SWSGIUtils.environFor(request: request)
        environ["SERVER_NAME"] = serverName
        environ["SERVER_PORT"] = String(serverPort)
        environ["SERVER_PROTOCOL"] = "HTTP/1.1"

        // set SWSGI keys
        environ["swsgi.version"] = "0.1"
        environ["swsgi.url_scheme"] = "http"
        environ["swsgi.input"] = { [unowned self] (handler: ((Data) -> Void)?) in
            self.swsgiInput(handler)
        }
        // TODO: add output file for error
        environ["swsgi.error"] = ""
        environ["swsgi.multithread"] = false
        environ["swsgi.multiprocess"] = false
        environ["swsgi.run_once"] = false

        // set embassy specific keys
        environ["embassy.connection"] = self
        environ["embassy.event_loop"] = eventLoop
        environ["embassy.headers"] = headers

        environ["embassy.version"] = Embassy.version

        if let contentLength = request.headers["Content-Length"], let length = Int(contentLength) {
            self.contentLength = length
        }

        // change state for incoming request to
        requestState = .readingBody
        // pause the reading for now, let `swsgi.input` called and resume it later
        transport.resume(reading: false)

        app(
            environ,
            { self.startResponse($0, headers: $1) },
            { self.sendBody($0) }
        )
    }

    private func swsgiInput(_ handler: ((Data) -> Void)?) {
        inputHandler = handler
        // reading handler provided
        if handler != nil {
            if let initialBody = initialBody {
                if !initialBody.isEmpty {
                    handleBodyData(initialBody)
                }
                self.initialBody = nil
            }
            transport.resume(reading: true)
            logger.info("Resume reading")
        // if the input handler is set to nil, it means pause reading
        } else {
            logger.info("Pause reading")
            transport.resume(reading: false)
        }
    }

    private func handleBodyData(_ data: Data) {
        guard let handler = inputHandler else {
            fatalError("Not suppose to read body data when input handler is not provided")
        }
        handler(data)
        readDataLength += data.count
        // we finish reading all the content, send EOF to input handler
        if let length = contentLength, readDataLength >= length {
            handler(Data())
            inputHandler = nil
        }
    }

    private func startResponse(_ status: String, headers: [(String, String)]) {
        guard case .sendingHeader = responseState else {
            logger.error("Response is not ready for sending header")
            return
        }
        var headers = headers
        // a handful of headers: a linear case-insensitive scan beats building a dictionary
        func hasHeader(_ name: String) -> Bool {
            headers.contains { $0.0.caseInsensitiveCompare(name) == .orderedSame }
        }
        // we don't support keep-alive connection for now, just force it to be closed
        if !hasHeader("Connection") {
            headers.append(("Connection", "close"))
        }
        if !hasHeader("Server") {
            headers.append(("Server", "Embassy"))
        }
        logger.debug("Start response, status=\(status.debugDescription), headers=\(headers.debugDescription)")
        let headersPart = headers.map { (key, value) in
            "\(key): \(value)"
        }.joined(separator: "\r\n")
        let parts = [
            "HTTP/1.1 \(status)",
            headersPart,
            "\r\n"
        ]
        transport.write(string: parts.joined(separator: "\r\n"))
        responseState = .sendingBody
    }

    private func sendBody(_ data: Data) {
        guard case .sendingBody = responseState else {
            logger.error("Response is not ready for sending body")
            return
        }
        guard !data.isEmpty else {
            // TODO: support keep-alive connection here?
            logger.info("Finish response")
            transport.close()
            return
        }
        transport.write(data: data)
    }

    // called to handle connection closed
    private func handleConnectionClosed(_ reason: Transport.CloseReason) {
        logger.info("Connection closed, reason=\(reason)")
        close()
        if let handler = inputHandler {
            handler(Data())
            inputHandler = nil
        }
        if let callback = closedCallback {
            callback()
        }
    }
}

extension HTTPConnection: Equatable {
}

public func == (lhs: HTTPConnection, rhs: HTTPConnection) -> Bool {
    lhs.uuid == rhs.uuid
}

extension HTTPConnection: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
