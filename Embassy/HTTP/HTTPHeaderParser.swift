//
//  HTTPHeaderParser.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Parser for HTTP headers
public struct HTTPHeaderParser {
    private static let CR = UInt8(13)
    private static let LF = UInt8(10)
    private static let NEWLINE = (CR, LF)

    public enum Element {
        case Head(method: String, path: String, version: String)
        case Header(key: String, value: String)
        case End(bodyPart: [UInt8])
    }

    private enum State {
        case Head
        case Headers
    }
    private var state: State = .Head
    private var buffer: [UInt8] = []

    /// Feed data to HTTP parser
    ///  - Parameter data: the data to feed
    ///  - Returns: parsed headers elements
    mutating func feed(data: [UInt8]) -> [Element] {
        buffer += data
        var elements = [Element]()
        while buffer.count > 0 {
            // pair of (0th, 1st), (1st, 2nd), (2nd, 3rd) ... chars, so that we can find <LF><CR>
            let charPairs: [(UInt8, UInt8)] = Array(zip(
                buffer[0..<buffer.count - 1],
                buffer[1..<buffer.count]
            ))
            // ensure we have <CR><LF> in current buffer
            guard let index = (charPairs).indexOf({ $0 == HTTPHeaderParser.NEWLINE }) else {
                // no <CR><LF> found, just return the current elements
                return elements
            }
            let bytes = Array(buffer[0..<index])
            let string = String(bytes: bytes, encoding: NSUTF8StringEncoding)!
            buffer = Array(buffer[(index + 2)..<buffer.count])

            // TODO: the initial usage of this HTTP server is for iOS API server mocking only,
            // we don't usually see malform requests, but if it's necessary, like if we want to put
            // this server in real production, we should handle malform header then
            switch state {
            case .Head:
                let parts = string.componentsSeparatedByString(" ")
                elements.append(.Head(method: parts[0], path: parts[1], version: parts[2..<parts.count].joinWithSeparator(" ")))
                state = .Headers
            case .Headers:
                // end of headers
                guard bytes.count > 0 else {
                    elements.append(.End(bodyPart: buffer))
                    return elements
                }
                let parts = string.componentsSeparatedByString(": ")
                elements.append(.Header(key: parts[0], value: parts[1..<parts.count].joinWithSeparator(": ")))
            }
        }
        return elements
    }
}
