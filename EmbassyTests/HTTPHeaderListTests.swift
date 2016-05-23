//
//  HTTPHeaderListTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/23/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class HTTPHeaderListTests: XCTestCase {

    func testHeaderList() {
        let list = HTTPHeaderList(headers: [
            ("Content-Type", "text/html"),
            ("Content-Length", "1234"),
            ("Set-Cookie", "foo=bar"),
            ("Set-Cookie", "egg=spam")
        ])
        
        XCTAssertNil(list["Not-Exists"])
        XCTAssertNil(list.getValuesFor("Not-Exists"))
        
        XCTAssertEqual(list["Content-Type"], "text/html")
        XCTAssertEqual(list["content-type"], "text/html")
        XCTAssertEqual(list.getValuesFor("Content-Type")!, ["text/html"])
        XCTAssertEqual(list.getValuesFor("content-type")!, ["text/html"])
        
        XCTAssertEqual(list["Content-Length"], "1234")
        XCTAssertEqual(list["CONTENT-LENGTH"], "1234")
        XCTAssertEqual(list.getValuesFor("Content-Length")!, ["1234"])
        XCTAssertEqual(list.getValuesFor("CONTENT-LENGTH")!, ["1234"])
        
        XCTAssertEqual(list["Set-Cookie"], "foo=bar")
        XCTAssertEqual(list["Set-cookie"], "foo=bar")
        XCTAssertEqual(list.getValuesFor("Set-Cookie")!, ["foo=bar", "egg=spam"])
        XCTAssertEqual(list.getValuesFor("Set-cookie")!, ["foo=bar", "egg=spam"])
    }


}
