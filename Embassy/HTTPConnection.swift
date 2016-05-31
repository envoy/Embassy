//
//  HTTPConnection.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation



/// HTTPConnection represents an active HTTP connection
public final class HTTPConnection {
    enum RequestState {
        case ParsingHeader
        case ReadingBody
    }
    
    enum ResponseState {
        case SendingHeader
        case SendingBody
    }

    let logger = Logger()
    public let uuid: String = NSUUID().UUIDString
    public let transport: Transport
    public let app: SWSGI
    public let serverName: String
    public let serverPort: Int
    /// Callback to be called when this connection closed
    var closedCallback: (Void -> Void)?
    
    private(set) var requestState: RequestState = .ParsingHeader
    private(set) var responseState: ResponseState = .SendingHeader
    private(set) public var eventLoop: EventLoopType!
    private var headerParser: HTTPHeaderParser!
    private var headerElements: [HTTPHeaderParser.Element] = []
    private var request: HTTPRequest!
    private var initialBody: [UInt8]?
    private var inputHandler: ([UInt8] -> Void)?
    // total content length to read
    private var contentLength: Int?
    // total data bytes we've already read
    private var readDataLength: Int = 0
    
    public init(app: SWSGI, serverName: String, serverPort: Int, transport: Transport, eventLoop: EventLoopType, closedCallback: (Void -> Void)? = nil) {
        self.app = app
        self.serverName = serverName
        self.serverPort = serverPort
        self.transport = transport
        self.eventLoop = eventLoop
        self.closedCallback = closedCallback
        
        transport.readDataCallback = handleDataReceived
        transport.closedCallback = handleConnectionClosed
    }
    
    public func close() {
        transport.close()
    }
    
    // called to handle data received
    private func handleDataReceived(data: [UInt8]) {
        switch requestState {
        case .ParsingHeader:
            handleHeaderData(data)
        case .ReadingBody:
            handleBodyData(data)
        }
    }
    
    // called to handle header data
    private func handleHeaderData(data: [UInt8]) {
        if headerParser == nil {
            headerParser = HTTPHeaderParser()
        }
        headerElements += headerParser.feed(data)
        // we only handle when there are elements in header parser
        guard let lastElement = headerElements.last else {
            return
        }
        // we only handle the it when we get the end of header
        guard case .End = lastElement else {
            return
        }
        
        var method: String!
        var path: String!
        var version: String!
        var headers: [(String, String)] = []
        for element in headerElements {
            switch element {
            case .Head(let headMethod, let headPath, let headVersion):
                method = headMethod
                path = headPath
                version = headVersion
            case .Header(let key, let value):
                headers.append((key, value))
            case .End(let bodyPart):
                initialBody = bodyPart
            }
        }
        logger.debug("Header parsed, method=\(method), path=\(path.debugDescription), version=\(version.debugDescription), headers=\(headers)")
        request = HTTPRequest(
            method: HTTPRequest.Method.fromString(method),
            path: path,
            version: version,
            rawHeaders: headers
        )
        var environ = SWSGIUtils.environForRequest(request)
        environ["SERVER_NAME"] = serverName
        environ["SERVER_PORT"] = String(serverPort)
        environ["SERVER_PROTOCOL"] = "HTTP/1.1"
        
        // set SWSGI keys
        environ["swsgi.version"] = "0.1"
        environ["swsgi.url_scheme"] = "http"
        environ["swsgi.input"] = swsgiInput
        // TODO: add output file for error
        environ["swsgi.error"] = ""
        environ["swsgi.multithread"] = false
        environ["swsgi.multiprocess"] = false
        environ["swsgi.run_once"] = false
        
        // set embassy specific keys
        environ["embassy.connection"] = self
        environ["embassy.event_loop"] = eventLoop as? AnyObject
        
        if
            let contentLength = request.headers["Content-Length"],
            let length = Int(contentLength)
        {
            self.contentLength = length
        }
        
        // change state for incoming request to
        requestState = .ReadingBody
        // pause the reading for now, let `swsgi.input` called and resume it later
        transport.resumeReading(false)
        
        app(environ: environ, startResponse: startResponse, sendBody: sendBody)
    }
    
    private func swsgiInput(handler: ([UInt8] -> Void)?) {
        inputHandler = handler
        // reading handler provided
        if let handler = handler {
            if let initialBody = initialBody {
                handler(initialBody)
                readDataLength += initialBody.count
                self.initialBody = nil
            }
            transport.resumeReading(true)
        // if the input handler is set to nil, it means pause reading
        } else {
            transport.resumeReading(false)
        }
    }
    
    private func handleBodyData(data: [UInt8]) {
        guard let handler = inputHandler else {
            fatalError("Not suppose to read body data when input handler is not provided")
        }
        handler(data)
        readDataLength += data.count
        // we finish reading all the content, send EOF to input handler
        if let length = contentLength where readDataLength >= length {
            handler([])
            inputHandler = nil
        }
    }
    
    private func startResponse(status: String, headers: [(String, String)]) {
        guard case .SendingHeader = responseState else {
            logger.error("Response is not ready for sending header")
            return
        }
        var headers = headers
        let headerList = HTTPHeaderList(headers: headers)
        // we don't support keep-alive connection for now, just force it to be closed
        if headerList["Connection"] == nil {
            headers.append(("Connection", "close"))
        }
        if headerList["Server"] == nil {
            headers.append(("Server", "Embassy"))
        }
        logger.debug("Start response, status=\(status.debugDescription), headers=\(headers.debugDescription)")
        let headersPart = headers.map { (key, value) in
            return "\(key): \(value)"
        }.joinWithSeparator("\r\n")
        let parts = [
            "HTTP/1.1 \(status)",
            headersPart,
            "\r\n"
        ]
        transport.writeUTF8(parts.joinWithSeparator("\r\n"))
        responseState = .SendingBody
    }
    
    private func sendBody(data: [UInt8]) {
        guard case .SendingBody = responseState else {
            logger.error("Response is not ready for sending body")
            return
        }
        guard data.count > 0 else {
            // TODO: support keep-alive connection here?
            logger.info("Finish response")
            transport.close()
            return
        }
        transport.write(data)
    }
    
    // called to handle connection closed
    private func handleConnectionClosed(reason: Transport.CloseReason) {
        logger.info("Connection closed")
        close()
        if let handler = inputHandler {
            handler([])
            inputHandler = nil
        }
        if let callback = closedCallback {
            callback()
        }
    }
}

extension HTTPConnection: Equatable {
}

public func ==(lhs: HTTPConnection, rhs: HTTPConnection) -> Bool {
    return lhs.uuid == rhs.uuid
}

extension HTTPConnection: Hashable {
    public var hashValue: Int {
        return uuid.hashValue
    }
}
