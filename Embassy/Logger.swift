//
//  Logger.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public final class Logger: LoggerType {
    let name: String
    let level: LogLevel
    private(set) var handlers: [LogHandlerType] = []

    init(name: String, level: LogLevel = .INFO) {
        self.name = name
        self.level = level
    }

    init(fileName: String = #file, level: LogLevel = .INFO) {
        self.name = Logger.moduleNameForFileName(fileName)
        self.level = level
    }

    /// Add handler to self logger
    ///  - Parameter handler: the handler to add
    func addHandler(handler: LogHandlerType) {
        handlers.append(handler)
    }

    func debug(
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(.DEBUG, message: message, caller: caller, file: file, line: line)
    }

    func info(
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(.INFO, message: message, caller: caller, file: file, line: line)
    }

    func warning(
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(.WARNING, message: message, caller: caller, file: file, line: line)
    }

    func error(
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(.ERROR, message: message, caller: caller, file: file, line: line)
    }

    func critical(
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(.CRITICAL, message: message, caller: caller, file: file, line: line)
    }

    func log(
        level: LogLevel,
        @autoclosure message: Void -> String,
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        let record = LogRecord(
            loggerName: name,
            level: level,
            message: message(),
            file: file,
            function: caller,
            line: line,
            time: NSDate()
        )
        log(record)
    }

    func log(record: LogRecord) {
        guard record.level.rawValue >= level.rawValue else {
            return
        }
        for handler in handlers {
            handler.emit(record)
        }
    }

    /// Strip file name and return only the name part, e.g. /path/to/MySwiftModule.swift will be
    /// MySwiftModule
    ///  - Parameter fileName: file name to be stripped
    ///  - Returns: stripped file name
    static func moduleNameForFileName(fileName: String) -> String {
        return ((fileName as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
    }
}
