//
//  Errors.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Error from operation system
public enum OSError: ErrorType {
    case IOError(number: Int, message: String)
    /// Return a socket error with the last error number and description
    static func lastIOError() -> OSError {
        return .IOError(number: Int(errno), message: lastErrorDescription())
    }
}

/// Return description for last error
func lastErrorDescription() -> String {
    return String.fromCString(UnsafePointer(strerror(errno))) ?? "Unknown Error: \(errno)"
}
