//
//  HTTPHeaderParserTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import XCTest

@testable import Embassy

#if os(Linux)
    extension HTTPHeaderParserTests {
        static var allTests = [
            ("testSimpleParsing", testSimpleParsing),
            ("testPartialParsing", testPartialParsing),
            ("testHeaders", testHeaders),
            ("testColonInHeader", testColonInHeader),
            ("testNoSpaceAfterColonForHeader", testNoSpaceAfterColonForHeader),
            ("testStripLeadingSpaces", testStripLeadingSpaces),
        ]
    }
#endif

extension HTTPHeaderParser.Element: Equatable {
}
public func == (lhs: HTTPHeaderParser.Element, rhs: HTTPHeaderParser.Element) -> Bool {
    switch lhs {
    case .head(let lhsMethod, let lhsPath, let lhsVersion):
        if case .head(let rhsMethod, let rhsPath, let rhsVersion) = rhs {
            return (lhsMethod == rhsMethod && lhsPath == rhsPath && lhsVersion == rhsVersion)
        }
    case .header(let lhsKey, let lhsValue):
        if case .header(let rhsKey, let rhsValue) = rhs {
            return (lhsKey == rhsKey && lhsValue == rhsValue)
        }
    case .end(let lhsBody):
        if case .end(let rhsBody) = rhs {
            return (lhsBody == rhsBody)
        }
    }
    return false
}

class HTTPHeaderParserTests: XCTestCase {

    func testSimpleParsing() {
        let header = "GET /index.html HTTP/1.1\r\nHost: www.example.com\r\n\r\nbody goes here"
        var parser = HTTPHeaderParser()
        let elements = parser.feed(Data(header.utf8))
        XCTAssertEqual(elements, [
            HTTPHeaderParser.Element.head(method: "GET", path: "/index.html", version: "HTTP/1.1"),
            HTTPHeaderParser.Element.header(key: "Host", value: "www.example.com"),
            HTTPHeaderParser.Element.end(bodyPart: Data("body goes here".utf8))
        ])
    }

    func testPartialParsing() {
        let line1Part1 = "GET /index.html"
        let line1Part2 = " HTTP/1.1\r\n"

        let line2Part1 = "Host: www.exam"
        let line2Part2 = "ple.com\r"
        let line2Part3 = "\n"

        let line3Part1 = "\r"
        let line3Part2 = "\nhere comes the body"

        var parser = HTTPHeaderParser()

        // try to feed empty array
        XCTAssertEqual(parser.feed(Data()), [])

        XCTAssertEqual(parser.feed(Data(line1Part1.utf8)), [])
        XCTAssertEqual(parser.feed(Data(line1Part2.utf8)), [
            HTTPHeaderParser.Element.head(method: "GET", path: "/index.html", version: "HTTP/1.1")
        ])

        XCTAssertEqual(parser.feed(Data(line2Part1.utf8)), [])
        XCTAssertEqual(parser.feed(Data(line2Part2.utf8)), [])
        XCTAssertEqual(parser.feed(Data(line2Part3.utf8)), [
            HTTPHeaderParser.Element.header(key: "Host", value: "www.example.com"),
        ])

        // try to feed empty array
        XCTAssertEqual(parser.feed(Data()), [])

        XCTAssertEqual(parser.feed(Data(line3Part1.utf8)), [])
        XCTAssertEqual(parser.feed(Data(line3Part2.utf8)), [
            HTTPHeaderParser.Element.end(bodyPart: Data("here comes the body".utf8))
        ])
    }

    func testHeaders() {
        let header = [
            "GET /index.html HTTP/1.1",
            "Host: foobar.com",
            "Date: Mon, 23 May 2005 22:38:34 GMT",
            "Content-Type: text/html; charset=UTF-8",
            "Content-Encoding: UTF-8",
            "Content-Length: 138",
            "Last-Modified: Wed, 08 Jan 2003 23:11:55 GMT",
            "Server: Apache/1.3.3.7 (Unix) (Red-Hat/Linux)",
            "ETag: \"3f80f-1b6-3e1cb03b\"",
            "Accept-Ranges: bytes",
            "Connection: close"
        ].joined(separator: "\r\n") + "\r\n\r\n"
        var parser = HTTPHeaderParser()
        let elements = parser.feed(Data(header.utf8))
        XCTAssertEqual(elements, [
            HTTPHeaderParser.Element.head(method: "GET", path: "/index.html", version: "HTTP/1.1"),
            HTTPHeaderParser.Element.header(key: "Host", value: "foobar.com"),
            HTTPHeaderParser.Element.header(key: "Date", value: "Mon, 23 May 2005 22:38:34 GMT"),
            HTTPHeaderParser.Element.header(key: "Content-Type", value: "text/html; charset=UTF-8"),
            HTTPHeaderParser.Element.header(key: "Content-Encoding", value: "UTF-8"),
            HTTPHeaderParser.Element.header(key: "Content-Length", value: "138"),
            HTTPHeaderParser.Element.header(key: "Last-Modified", value: "Wed, 08 Jan 2003 23:11:55 GMT"),
            HTTPHeaderParser.Element.header(key: "Server", value: "Apache/1.3.3.7 (Unix) (Red-Hat/Linux)"),
            HTTPHeaderParser.Element.header(key: "ETag", value: "\"3f80f-1b6-3e1cb03b\""),
            HTTPHeaderParser.Element.header(key: "Accept-Ranges", value: "bytes"),
            HTTPHeaderParser.Element.header(key: "Connection", value: "close"),
            HTTPHeaderParser.Element.end(bodyPart: Data())
        ])
    }

    func testColonInHeader() {
        let header = [
            "GET /index.html HTTP/1.1",
            "Host: foobar.com",
            "X-My-Header: MyFaboriteColor: Green",
            "Connection: close"
        ].joined(separator: "\r\n") + "\r\n\r\n"
        var parser = HTTPHeaderParser()
        let elements = parser.feed(Data(header.utf8))
        XCTAssertEqual(elements, [
            HTTPHeaderParser.Element.head(method: "GET", path: "/index.html", version: "HTTP/1.1"),
            HTTPHeaderParser.Element.header(key: "Host", value: "foobar.com"),
            HTTPHeaderParser.Element.header(key: "X-My-Header", value: "MyFaboriteColor: Green"),
            HTTPHeaderParser.Element.header(key: "Connection", value: "close"),
            HTTPHeaderParser.Element.end(bodyPart: Data())
        ])
    }

    func testNoSpaceAfterColonForHeader() {
        let header = [
            "GET /index.html HTTP/1.1",
            "Host: foobar.com",
            "X-My-Header:MyFaboriteColor: Green",
            "Connection:close"
            ].joined(separator: "\r\n") + "\r\n\r\n"
        var parser = HTTPHeaderParser()
        let elements = parser.feed(Data(header.utf8))
        XCTAssertEqual(elements, [
            HTTPHeaderParser.Element.head(method: "GET", path: "/index.html", version: "HTTP/1.1"),
            HTTPHeaderParser.Element.header(key: "Host", value: "foobar.com"),
            HTTPHeaderParser.Element.header(key: "X-My-Header", value: "MyFaboriteColor: Green"),
            HTTPHeaderParser.Element.header(key: "Connection", value: "close"),
            HTTPHeaderParser.Element.end(bodyPart: Data())
        ])
    }

    func testStripLeadingSpaces() {
        XCTAssertEqual("x".withoutLeadingSpaces, "x")
        XCTAssertEqual("eggsspam".withoutLeadingSpaces, "eggsspam")
        XCTAssertEqual("foo bar".withoutLeadingSpaces, "foo bar")
        XCTAssertEqual("foo bar ".withoutLeadingSpaces, "foo bar ")
        XCTAssertEqual(" foo bar ".withoutLeadingSpaces, "foo bar ")
        XCTAssertEqual("  foo bar ".withoutLeadingSpaces, "foo bar ")
        XCTAssertEqual("   ".withoutLeadingSpaces, "")
        XCTAssertEqual("".withoutLeadingSpaces, "")
    }

}
