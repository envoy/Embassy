//
//  DefaultLoggerTests.swift
//  Embassy
//

import XCTest

@testable import Embassy

// test double; only ever touched from the test thread
private final class RecordingLogHandler: LogHandler, @unchecked Sendable {
    var formatter: LogFormatter?
    var records: [LogRecord] = []

    func emit(record: LogRecord) {
        records.append(record)
    }
}

class DefaultLoggerTests: XCTestCase {

    func testMessageBelowLevelIsNotEvaluated() {
        let handler = RecordingLogHandler()
        let logger = DefaultLogger(name: "test", level: .info)
        logger.add(handler: handler)

        var evaluations = 0
        func expensiveMessage() -> String {
            evaluations += 1
            return "expensive"
        }

        logger.debug(expensiveMessage())
        XCTAssertEqual(evaluations, 0, "suppressed log must not evaluate its message")
        XCTAssertTrue(handler.records.isEmpty)

        logger.info(expensiveMessage())
        XCTAssertEqual(evaluations, 1)
        XCTAssertEqual(handler.records.map(\.message), ["expensive"])
        XCTAssertEqual(handler.records.first?.level, .info)
    }

    func testLogRecordStillRespectsLevel() {
        let handler = RecordingLogHandler()
        let logger = DefaultLogger(name: "test", level: .warning)
        logger.add(handler: handler)

        let record = LogRecord(
            loggerName: "other", level: .info, message: "m",
            file: #file, function: #function, line: #line, time: Date()
        )
        logger.log(record: record)
        XCTAssertTrue(handler.records.isEmpty)
    }
}
