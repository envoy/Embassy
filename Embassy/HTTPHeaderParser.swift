//
//  HTTPHeaderParser.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Parser for HTTP headers
struct HTTPHeaderParser {
    enum Header {
        case Status(code: Int, message: String)
        case Header(key: String, value: String)
    }
    
    /// Feed data to HTTP parser
    ///  - Parameter data: the data to feed
    ///  - Returns: parsed headers
    func feed(data: [UInt8]) -> [Header] {
        // TODO: parse the header here
        return []
    }
}
