//
//  Logger.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public enum LogLevel: Int, Sendable {
    case notset = 0
    case debug = 10
    case info = 20
    case warning = 30
    case error = 40
    case critical = 50

    var name: String {
        switch self {
        case .notset:
            "NOTSET"
        case .debug:
            "DEBUG"
        case .info:
            "INFO"
        case .warning:
            "WARNING"
        case .error:
            "ERROR"
        case .critical:
            "CRITICAL"
        }
    }
}

public struct LogRecord: Sendable {
    let loggerName: String
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int
    let time: Date
}

extension LogRecord {
    /// Overwrite message and return a new record
    ///  - Parameter overwrite: closure to accept self record and return overwritten string
    ///  - Returns: the overwritten log record
    public func overwriteMessage(overwrite: ((LogRecord) -> String)) -> LogRecord {
        return LogRecord(
            loggerName: loggerName,
            level: level,
            message: overwrite(self),
            file: file,
            function: function,
            line: line,
            time: time
        )
    }
}

/// Loggers are shared across threads (a connection logger propagates to the server logger),
/// so conformers must be safe to call from any thread.
public protocol Logger: Sendable {
    /// Add a handler to the logger
    func add(handler: LogHandler)

    /// Write log record to logger
    func log(record: LogRecord)
}
