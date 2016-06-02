//
//  PropagateLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler which propagates record to another logger
public struct PropagateLogHandler: LogHandlerType {
    let logger: LoggerType
    var formatter: LogFormatterType?

    init(logger: LoggerType) {
        self.logger = logger
    }

    func emit(record: LogRecord) {
        logger.log(record)
    }
}
