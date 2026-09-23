//
//  TransformLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler transforms record and relays it to another handler
public struct TransformLogHandler: LogHandler {
    public let handler: LogHandler
    public var formatter: LogFormatter?
    public let transform: @Sendable (LogRecord) -> LogRecord

    public init(handler: LogHandler, transform: @escaping @Sendable (LogRecord) -> LogRecord) {
        self.handler = handler
        self.transform = transform
    }

    public func emit(record: LogRecord) {
        handler.emit(record: transform(record))
    }
}
