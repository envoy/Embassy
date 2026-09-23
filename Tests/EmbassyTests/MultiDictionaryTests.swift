//
//  MultiDictionaryTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Testing

@testable import Embassy

@Suite struct MultiDictionaryTests {
    @Test func caseInsensitiveMultiDictionary() {
        let dict = MultiDictionary<String, String, LowercaseKeyTransform>(items: [
            ("Content-Type", "text/html"),
            ("Content-Length", "1234"),
            ("Set-cookie", "foo=bar"),
            ("Set-Cookie", "egg=spam")
        ])

        #expect(dict["Not-Exists"] == nil)
        #expect(dict.valuesFor(key: "Not-Exists") == nil)

        #expect(dict["Content-Type"] == "text/html")
        #expect(dict["content-type"] == "text/html")
        #expect(dict.valuesFor(key: "Content-Type") == ["text/html"])
        #expect(dict.valuesFor(key: "Content-type") == ["text/html"])

        #expect(dict["Content-Length"] == "1234")
        #expect(dict["CONTENT-LENGTH"] == "1234")
        #expect(dict.valuesFor(key: "Content-Length") == ["1234"])
        #expect(dict.valuesFor(key: "CONTENT-LENGTH") == ["1234"])

        #expect(dict["Set-Cookie"] == "foo=bar")
        #expect(dict["Set-cookie"] == "foo=bar")
        #expect(dict.valuesFor(key: "Set-Cookie") == ["foo=bar", "egg=spam"])
        #expect(dict.valuesFor(key: "Set-cookie") == ["foo=bar", "egg=spam"])
    }

    @Test func caseSensitiveMultiDictionary() {
        let dict = MultiDictionary<String, String, NoOpKeyTransform<String>>(items: [
            ("Foo", "Bar"),
            ("egg", "spam"),
            ("Egg", "Spam"),
            ("egg", "bacon")
        ])

        #expect(dict["Not-Exists"] == nil)
        #expect(dict.valuesFor(key: "Not-Exists") == nil)
        #expect(dict.valuesFor(key: "foo") == nil)
        #expect(dict.valuesFor(key: "FOO") == nil)
        #expect(dict.valuesFor(key: "EGG") == nil)

        #expect(dict["Foo"] == "Bar")
        #expect(dict.valuesFor(key: "Foo") == ["Bar"])

        #expect(dict["egg"] == "spam")
        #expect(dict.valuesFor(key: "egg") == ["spam", "bacon"])

        #expect(dict["Egg"] == "Spam")
        #expect(dict.valuesFor(key: "Egg") == ["Spam"])
    }

    @Test func arrayLiteralMatchesItemsInit() {
        let literal: MultiDictionary<String, String, LowercaseKeyTransform> = [("A", "1"), ("a", "2")]
        #expect(literal.valuesFor(key: "a") == ["1", "2"])
        #expect(literal.count == 2)
    }
}
