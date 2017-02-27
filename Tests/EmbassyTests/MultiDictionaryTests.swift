//
//  MultiDictionaryTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

#if os(Linux)
    extension MultiDictionaryTests {
        static var allTests = [
            ("testCaseInsenstiveMultiDictionary", testCaseInsenstiveMultiDictionary),
            ("testCaseSenstiveMultiDictionary", testCaseSenstiveMultiDictionary),
        ]
    }
#endif

class MultiDictionaryTests: XCTestCase {
    func testCaseInsenstiveMultiDictionary() {
        let dict = MultiDictionary<String, String, LowercaseKeyTransform>(items: [
            ("Content-Type", "text/html"),
            ("Content-Length", "1234"),
            ("Set-cookie", "foo=bar"),
            ("Set-Cookie", "egg=spam")
        ])

        XCTAssertNil(dict["Not-Exists"])
        XCTAssertNil(dict.valuesFor(key: "Not-Exists"))

        XCTAssertEqual(dict["Content-Type"], "text/html")
        XCTAssertEqual(dict["content-type"], "text/html")
        XCTAssertEqual(dict.valuesFor(key: "Content-Type")!, ["text/html"])
        XCTAssertEqual(dict.valuesFor(key: "Content-type")!, ["text/html"])

        XCTAssertEqual(dict["Content-Length"], "1234")
        XCTAssertEqual(dict["CONTENT-LENGTH"], "1234")
        XCTAssertEqual(dict.valuesFor(key: "Content-Length")!, ["1234"])
        XCTAssertEqual(dict.valuesFor(key: "CONTENT-LENGTH")!, ["1234"])

        XCTAssertEqual(dict["Set-Cookie"], "foo=bar")
        XCTAssertEqual(dict["Set-cookie"], "foo=bar")
        XCTAssertEqual(dict.valuesFor(key: "Set-Cookie")!, ["foo=bar", "egg=spam"])
        XCTAssertEqual(dict.valuesFor(key: "Set-cookie")!, ["foo=bar", "egg=spam"])
    }

    func testCaseSenstiveMultiDictionary() {
        let dict = MultiDictionary<String, String, NoOpKeyTransform<String>>(items: [
            ("Foo", "Bar"),
            ("egg", "spam"),
            ("Egg", "Spam"),
            ("egg", "bacon")
        ])

        XCTAssertNil(dict["Not-Exists"])
        XCTAssertNil(dict.valuesFor(key: "Not-Exists"))
        XCTAssertNil(dict.valuesFor(key: "foo"))
        XCTAssertNil(dict.valuesFor(key: "FOO"))
        XCTAssertNil(dict.valuesFor(key: "EGG"))

        XCTAssertEqual(dict["Foo"], "Bar")
        XCTAssertEqual(dict.valuesFor(key: "Foo")!, ["Bar"])

        XCTAssertEqual(dict["egg"], "spam")
        XCTAssertEqual(dict.valuesFor(key: "egg")!, ["spam", "bacon"])

        XCTAssertEqual(dict["Egg"], "Spam")
        XCTAssertEqual(dict.valuesFor(key: "Egg")!, ["Spam"])
    }
}
