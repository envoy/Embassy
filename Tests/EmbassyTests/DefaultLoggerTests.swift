//
//  DefaultLoggerTests.swift
//  Embassy
//

import Foundation
import Testing

@testable import Embassy

// test double; only ever touched from the test thread
private final class RecordingLogHandler: LogHandler, @unchecked Sendable {
    var formatter: LogFormatter?
    var records: [LogRecord] = []

    func emit(record: LogRecord) {
        records.append(record)
    }
}

@Suite struct DefaultLoggerTests {
    @Test func messageBelowLevelIsNotEvaluated() {
        let handler = RecordingLogHandler()
        let logger = DefaultLogger(name: "test", level: .info)
        logger.add(handler: handler)

        var evaluations = 0
        func expensiveMessage() -> String {
            evaluations += 1
            return "expensive"
        }

        logger.debug(expensiveMessage())
        #expect(evaluations == 0, "suppressed log must not evaluate its message")
        #expect(handler.records.isEmpty)

        logger.info(expensiveMessage())
        #expect(evaluations == 1)
        #expect(handler.records.map(\.message) == ["expensive"])
        #expect(handler.records.first?.level == .info)
    }

    @Test func logRecordStillRespectsLevel() {
        let handler = RecordingLogHandler()
        let logger = DefaultLogger(name: "test", level: .warning)
        logger.add(handler: handler)

        let record = LogRecord(
            loggerName: "other", level: .info, message: "m",
            file: #file, function: #function, line: #line, time: Date()
        )
        logger.log(record: record)
        #expect(handler.records.isEmpty)
    }

    @Test(arguments: [
        (LogLevel.notset, "NOTSET"), (.debug, "DEBUG"), (.info, "INFO"),
        (.warning, "WARNING"), (.error, "ERROR"), (.critical, "CRITICAL")
    ])
    func levelNames(level: LogLevel, name: String) {
        #expect(level.name == name)
    }
}
