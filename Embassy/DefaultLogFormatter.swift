//
//  DefaultLogFormatter.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

struct DefaultLogFormatter: LogFormatterType {
    func format(record: LogRecord) -> String {
        return "\(record.time) [\(record.level)] - \(record.loggerName): \(record.message)"
    }
}
