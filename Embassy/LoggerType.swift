//
//  LoggerType.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public enum LogLevel: Int {
    case NOTSET = 0
    case DEBUG = 10
    case INFO = 20
    case WARNING = 30
    case ERROR = 40
    case CRITICAL = 50

    var name: String {
        switch self {
        case .NOTSET:
            return "NOTSET"
        case .DEBUG:
            return "DEBUG"
        case .INFO:
            return "INFO"
        case .WARNING:
            return "WARNING"
        case .ERROR:
            return "ERROR"
        case .CRITICAL:
            return "CRITICAL"
        }
    }
}

public struct LogRecord {
    let loggerName: String
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int
    let time: NSDate
}

extension LogRecord {
    /// Overwrite message and return a new record
    ///  - Parameter overwrite: closure to accept self record and return overwritten string
    ///  - Returns: the overwritten log record
    func overwriteMessage(@noescape overwrite: (LogRecord -> String)) -> LogRecord {
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

protocol LoggerType {
    func log(record: LogRecord)
}
