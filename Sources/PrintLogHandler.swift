//
//  PrintLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler which prints (stdout) log records
public struct PrintLogHandler: LogHandler {
    public var formatter: LogFormatter?

    public init(formatter: LogFormatter? = DefaultLogFormatter()) {
        self.formatter = formatter
    }

    public func emit(record: LogRecord) {
        if let formatter = formatter {
            print(formatter.format(record: record))
        }
    }
}
