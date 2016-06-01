//
//  HTTPRequest.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public struct HTTPRequest {
    enum Method: CustomStringConvertible {
        case GET
        case HEAD
        case POST
        case PUT
        case DELETE
        case TRACE
        case OPTIONS
        case CONNECT
        case PATCH
        case OTHER(name: String)
        
        var description: String {
            switch self {
            case .GET:
                return "GET"
            case .HEAD:
                return "HEAD"
            case .POST:
                return "POST"
            case .PUT:
                return "PUT"
            case .DELETE:
                return "DELETE"
            case .TRACE:
                return "TRACE"
            case .OPTIONS:
                return "OPTIONS"
            case .CONNECT:
                return "CONNECT"
            case .PATCH:
                return "PATCH"
            case .OTHER(name: let name):
                return name
            }
        }
        
        static func fromString(name: String) -> Method {
            switch name.uppercaseString {
            case "GET":
                return .GET
            case "HEAD":
                return .HEAD
            case "POST":
                return .POST
            case "PUT":
                return .PUT
            case "DELETE":
                return .DELETE
            case "TRACE":
                return .TRACE
            case "OPTIONS":
                return .OPTIONS
            case "CONNECT":
                return .CONNECT
            case "PATCH":
                return .PATCH
            default:
                return .OTHER(name: name)
            }
        }
    }

    /// Request method
    let method: Method
    /// Request path
    let path: String
    /// Request HTTP version (e.g. HTTP/1.0)
    let version: String
    /// Request headers
    let headers: MultiDictionary<String, String, LowercaseKeyTransform>

    init(method: Method, path: String, version: String, headers: [(String, String)]) {
        self.method = method
        self.path = path
        self.version = version
        self.headers = MultiDictionary<String, String, LowercaseKeyTransform>(items: headers)
    }
}
