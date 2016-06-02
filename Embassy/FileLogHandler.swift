//
//  FileLogHandler.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/2/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// A log handler which writes log records to given file handle
public struct FileLogHandler: LogHandlerType {
    let fileHandle: NSFileHandle
    public var formatter: LogFormatterType?

    private let queue = dispatch_queue_create(
        "com.envoy.Embassy.logging.FileLogHandler.queue",
        DISPATCH_QUEUE_SERIAL
    )

    public init(fileHandle: NSFileHandle, formatter: LogFormatterType? = DefaultLogFormatter()) {
        self.fileHandle = fileHandle
        self.formatter = formatter
    }

    public func emit(record: LogRecord) {
        dispatch_async(queue) {
            if let formatter = self.formatter {
                let msg = formatter.format(record) + "\n"
                self.fileHandle.writeData(msg.dataUsingEncoding(NSUTF8StringEncoding)!)
                self.fileHandle.synchronizeFile()
            }
        }
    }

    public static func stderrHandler() -> FileLogHandler {
        return FileLogHandler(fileHandle: NSFileHandle.fileHandleWithStandardError())
    }
}
