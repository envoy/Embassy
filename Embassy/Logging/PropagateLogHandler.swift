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
    public let logger: LoggerType
    public var formatter: LogFormatterType?

    public init(logger: LoggerType) {
        self.logger = logger
    }

    public func emit(record: LogRecord) {
        logger.log(record)
    }
}
