//
//  DefaultLogFormatter.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

public struct DefaultLogFormatter: LogFormatter {
    public func format(record: LogRecord) -> String {
        "\(record.time) [\(record.level)] - \(record.loggerName): \(record.message)"
    }
}
