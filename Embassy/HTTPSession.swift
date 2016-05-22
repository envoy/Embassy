//
//  HTTPSession.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// HTTPSession represents an alive HTTP connection
public final class HTTPSession {
    enum State {
        case ParsingHeader
        case ReadingBody
    }
    
    let logger = Logger()
    let transport: Transport
    private(set) var state: State = .ParsingHeader
    private(set) weak var eventLoop: EventLoop!
    private var headerParser: HTTPHeaderParser!
    private var headerElements: [HTTPHeaderParser.Element] = []
    private var request: HTTPRequest!
    
    init(transport: Transport, eventLoop: EventLoop) {
        self.transport = transport
        self.eventLoop = eventLoop
        
        transport.readDataCallback = handleDataReceived
        transport.closedCallback = handleConnectionClosed
    }
    
    // called to handle data received
    private func handleDataReceived(data: [UInt8]) {
        switch state {
        case .ParsingHeader:
            handleHeaderData(data)
        case .ReadingBody:
            // TODO:
            break
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
        var body: [UInt8]!
        for element in headerElements {
            switch element {
            case .Head(let headMethod, let headPath, let headVersion):
                method = headMethod
                path = headPath
                version = headVersion
            case .Header(let key, let value):
                headers.append((key, value))
            case .End(let bodyPart):
                body = bodyPart
            }
        }
        logger.debug("Header parsed, method=\(method), path=\(path.debugDescription), version=\(version), headers=\(headers)")
        request = HTTPRequest(
            method: HTTPRequest.Method.fromString(method),
            path: path,
            version: version,
            headers: headers
        )
        // TODO: pass the initial body part
        // TODO: handle request here
        
        // XXX: just a dummy response here
        transport.writeUTF8("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nbody goes here")
        transport.close()
        
    }
    
    // called to handle connection closed
    private func handleConnectionClosed(reason: Transport.CloseReason) {
        
    }
}
