//
//  HTTPHeaderParser.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

extension String {
    /// String without leading spaces
    var withoutLeadingSpaces: String {
        String(drop(while: { $0 == " " }))
    }
}

/// Parser for HTTP headers
public struct HTTPHeaderParser {
    private static let CRLF = Data([UInt8(ascii: "\r"), UInt8(ascii: "\n")])

    public enum Element {
        case head(method: String, path: String, version: String)
        case header(key: String, value: String)
        case end(bodyPart: Data)
    }

    private enum State {
        case head
        case headers
    }
    private var state: State = .head
    private var buffer: Data = Data()

    /// Feed data to HTTP parser
    ///  - Parameter data: the data to feed
    ///  - Returns: parsed headers elements
    mutating func feed(_ data: Data) -> [Element] {
        buffer.append(data)
        var elements = [Element]()
        // Scan for the next <CR><LF>. `firstRange(of:)` is a single forward pass,
        // and consuming the line in place keeps each iteration proportional to
        // the line length rather than the whole remaining buffer.
        while let newline = buffer.firstRange(of: HTTPHeaderParser.CRLF) {
            let lineRange = buffer.startIndex..<newline.lowerBound
            let line = String(decoding: buffer[lineRange], as: UTF8.self)
            let lineIsEmpty = lineRange.isEmpty
            buffer.removeSubrange(buffer.startIndex..<newline.upperBound)

            // TODO: the initial usage of this HTTP server is for iOS API server mocking only,
            // we don't usually see malform requests, but if it's necessary, like if we want to put
            // this server in real production, we should handle malform header then
            switch state {
            case .head:
                let parts = line.components(separatedBy: " ")
                elements.append(.head(
                    method: parts[0],
                    path: parts[1],
                    version: parts[2..<parts.count].joined(separator: " ")
                ))
                state = .headers
            case .headers:
                // end of headers
                guard !lineIsEmpty else {
                    elements.append(.end(bodyPart: buffer))
                    return elements
                }
                let parts = line.components(separatedBy: ":")
                let key = parts[0]
                let value = parts[1..<parts.count].joined(separator: ":").withoutLeadingSpaces
                elements.append(.header(key: key, value: value))
            }
        }
        return elements
    }
}
