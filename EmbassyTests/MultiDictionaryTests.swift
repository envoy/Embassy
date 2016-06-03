//
//  MultiDictionaryTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class MultiDictionaryTests: XCTestCase {
    func testCaseInsenstiveMultiDictionary() {
        let dict = MultiDictionary<String, String, LowercaseKeyTransform>(items: [
            ("Content-Type", "text/html"),
            ("Content-Length", "1234"),
            ("Set-cookie", "foo=bar"),
            ("Set-Cookie", "egg=spam")
        ])

        XCTAssertNil(dict["Not-Exists"])
        XCTAssertNil(dict.valuesFor("Not-Exists"))

        XCTAssertEqual(dict["Content-Type"], "text/html")
        XCTAssertEqual(dict["content-type"], "text/html")
        XCTAssertEqual(dict.valuesFor("Content-Type")!, ["text/html"])
        XCTAssertEqual(dict.valuesFor("Content-type")!, ["text/html"])

        XCTAssertEqual(dict["Content-Length"], "1234")
        XCTAssertEqual(dict["CONTENT-LENGTH"], "1234")
        XCTAssertEqual(dict.valuesFor("Content-Length")!, ["1234"])
        XCTAssertEqual(dict.valuesFor("CONTENT-LENGTH")!, ["1234"])

        XCTAssertEqual(dict["Set-Cookie"], "foo=bar")
        XCTAssertEqual(dict["Set-cookie"], "foo=bar")
        XCTAssertEqual(dict.valuesFor("Set-Cookie")!, ["foo=bar", "egg=spam"])
        XCTAssertEqual(dict.valuesFor("Set-cookie")!, ["foo=bar", "egg=spam"])
    }

    func testCaseSenstiveMultiDictionary() {
        let dict = MultiDictionary<String, String, NoOpKeyTransform<String>>(items: [
            ("Foo", "Bar"),
            ("egg", "spam"),
            ("Egg", "Spam"),
            ("egg", "bacon")
        ])

        XCTAssertNil(dict["Not-Exists"])
        XCTAssertNil(dict.valuesFor("Not-Exists"))
        XCTAssertNil(dict.valuesFor("foo"))
        XCTAssertNil(dict.valuesFor("FOO"))
        XCTAssertNil(dict.valuesFor("EGG"))

        XCTAssertEqual(dict["Foo"], "Bar")
        XCTAssertEqual(dict.valuesFor("Foo")!, ["Bar"])

        XCTAssertEqual(dict["egg"], "spam")
        XCTAssertEqual(dict.valuesFor("egg")!, ["spam", "bacon"])

        XCTAssertEqual(dict["Egg"], "Spam")
        XCTAssertEqual(dict.valuesFor("Egg")!, ["Spam"])
    }
}
