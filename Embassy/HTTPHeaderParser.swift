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
    private static let CR = UInt8(13)
    private static let LF = UInt8(10)
    
    enum Element {
        case Head(method: String, path: String, version: String)
        case Header(key: String, value: String)
        case End(bodyPart: [UInt8])
    }
    
    private enum State {
        case Head
        case Headers
    }
    private var state: State = .Head
    
    /// Feed data to HTTP parser
    ///  - Parameter data: the data to feed
    ///  - Returns: parsed headers elements
    func feed(data: [UInt8]) -> [Element] {
        
        switch state {
        case .Head:
            
            break
        case .Headers:
            break
        }
        
        // TODO: parse the header here
        return [.Head(method: "abc", path: "123", version: "1.0")]
    }
}
