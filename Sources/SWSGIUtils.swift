//
//  SWSGIUtils.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public struct SWSGIUtils {
    /// Transform given request into environ dictionary
    static func environFor(request: HTTPRequest) -> [String: Any] {
        var environ: [String: Any] = [
            "REQUEST_METHOD": String(describing: request.method),
            "SCRIPT_NAME": ""
        ]

        let queryParts = request.path.components(separatedBy: "?")
        if queryParts.count > 1 {
            environ["PATH_INFO"] = queryParts[0]
            environ["QUERY_STRING"] = queryParts[1..<queryParts.count].joined(separator: "?")
        } else {
            environ["PATH_INFO"] = request.path
        }
        if let contentType = request.headers["Content-Type"] {
            environ["CONTENT_TYPE"] = contentType
        }
        if let contentLength = request.headers["Content-Length"] {
            environ["CONTENT_LENGTH"] = contentLength
        }
        // header keys go in as HTTP_ + upper-cased, dash-to-underscore, e.g.
        // Content-Length -> HTTP_CONTENT_LENGTH; written straight into environ
        // rather than through a second dictionary that is then merged in
        environ.reserveCapacity(environ.count + request.headers.count)
        for (key, value) in request.headers {
            environ["HTTP_" + key.uppercased().replacingOccurrences(of: "-", with: "_")] = value
        }
        return environ
    }
}
