//
//  HTTPRequest.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public struct HTTPRequest {
    public enum Method: CustomStringConvertible {
        case get
        case head
        case post
        case put
        case delete
        case trace
        case options
        case connect
        case patch
        case other(name: String)

        public var description: String {
            switch self {
            case .get:
                "GET"
            case .head:
                "HEAD"
            case .post:
                "POST"
            case .put:
                "PUT"
            case .delete:
                "DELETE"
            case .trace:
                "TRACE"
            case .options:
                "OPTIONS"
            case .connect:
                "CONNECT"
            case .patch:
                "PATCH"
            case .other(name: let name):
                name
            }
        }

        public static func fromString(_ name: String) -> Method {
            switch name.uppercased() {
            case "GET":
                .get
            case "HEAD":
                .head
            case "POST":
                .post
            case "PUT":
                .put
            case "DELETE":
                .delete
            case "TRACE":
                .trace
            case "OPTIONS":
                .options
            case "CONNECT":
                .connect
            case "PATCH":
                .patch
            default:
                .other(name: name)
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

    public init(method: Method, path: String, version: String, headers: [(String, String)]) {
        self.method = method
        self.path = path
        self.version = version
        self.headers = MultiDictionary(items: headers)
    }
}
