//
//  PrintLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler which prints (stdout) log records
public struct PrintLogHandler: LogHandlerType {
    var formatter: LogFormatterType?

    init(formatter: LogFormatterType? = DefaultLogFormatter()) {
        self.formatter = formatter
    }

    func emit(record: LogRecord) {
        if let formatter = formatter {
            print(formatter.format(record))
        }
    }
}
