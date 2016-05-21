//
//  EventLoopTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class EventLoopTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.event-loop", DISPATCH_QUEUE_SERIAL)
    func testStop() {
        let selector = try! KqueueSelector()
        let loop = try! EventLoop(selector: selector)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), queue) {
            XCTAssert(loop.running)
            loop.stop()
            XCTAssertFalse(loop.running)
        }
        
        XCTAssertFalse(loop.running)
        assertExecutingTime(1.0, accuracy: 0.5) {
            loop.runForever()
        }
        XCTAssertFalse(loop.running)
    }
}
