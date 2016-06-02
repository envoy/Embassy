//
//  TransformLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler transforms record and relays it to another handler
public struct TransformLogHandler: LogHandlerType {
    public let handler: LogHandlerType
    public var formatter: LogFormatterType? = nil
    public let transform: (LogRecord) -> LogRecord

    public init(handler: LogHandlerType, transform: (LogRecord) -> LogRecord) {
        self.handler = handler
        self.transform = transform
    }

    public func emit(record: LogRecord) {
        handler.emit(transform(record))
    }
}
