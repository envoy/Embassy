//
//  HeapSortTetsts.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/25/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

#if os(Linux)
    extension HeapSortTetsts {
        static var allTests = [
            ("testPush", testPush),
            ("testPop", testPop),
            ("testSortWithRandomNumbers", testSortWithRandomNumbers),
            ("testSortWithRandomNumbersWithCustomCompareFunction", testSortWithRandomNumbersWithCustomCompareFunction),
        ]
    }
#endif

class HeapSortTetsts: XCTestCase {
    func testPush() {
        var heap: [Int] = []

        HeapSort.heapPush(&heap, item: 100)
        XCTAssertEqual(heap, [100])

        HeapSort.heapPush(&heap, item: 50)
        XCTAssertEqual(heap, [50, 100])

        HeapSort.heapPush(&heap, item: 25)
        XCTAssertEqual(heap, [25, 100, 50])

        HeapSort.heapPush(&heap, item: 49)
        XCTAssertEqual(heap, [25, 49, 50, 100])

        HeapSort.heapPush(&heap, item: 51)
        XCTAssertEqual(heap, [25, 49, 50, 100, 51])

        HeapSort.heapPush(&heap, item: 52)
        XCTAssertEqual(heap, [25, 49, 50, 100, 51, 52])

        HeapSort.heapPush(&heap, item: 48)
        XCTAssertEqual(heap, [25, 49, 48, 100, 51, 52, 50])
    }

    func testPop() {
        var heap = [25, 49, 48, 100, 51, 52, 50]

        XCTAssertEqual(HeapSort.heapPop(&heap), 25)
        XCTAssertEqual(heap, [48, 49, 50, 100, 51, 52])

        XCTAssertEqual(HeapSort.heapPop(&heap), 48)
        XCTAssertEqual(heap, [49, 51, 50, 100, 52])

        XCTAssertEqual(HeapSort.heapPop(&heap), 49)
        XCTAssertEqual(heap, [50, 51, 52, 100])

        XCTAssertEqual(HeapSort.heapPop(&heap), 50)
        XCTAssertEqual(heap, [51, 100, 52])

        XCTAssertEqual(HeapSort.heapPop(&heap), 51)
        XCTAssertEqual(heap, [52, 100])

        XCTAssertEqual(HeapSort.heapPop(&heap), 52)
        XCTAssertEqual(heap, [100])

        XCTAssertEqual(HeapSort.heapPop(&heap), 100)
        XCTAssertEqual(heap, [])
    }

    func testSortWithRandomNumbers() {
        let array: [UInt32] = Array(0..<100).map { _ in random() }
        var heap: [UInt32] = []
        for num in array {
            HeapSort.heapPush(&heap, item: num)
        }
        var resultArray: [UInt32] = []
        while !heap.isEmpty {
            resultArray.append(HeapSort.heapPop(&heap))
        }
        XCTAssertEqual(resultArray, array.sorted())
    }

    func testSortWithRandomNumbersWithCustomCompareFunction() {
        let array: [UInt32] = Array(0..<100).map { _ in random() }
        var heap: [UInt32] = []
        for num in array {
            HeapSort.heapPush(&heap, item: num, isOrderredBefore: >)
        }
        var resultArray: [UInt32] = []
        while !heap.isEmpty {
            resultArray.append(HeapSort.heapPop(&heap, isOrderredBefore: >))
        }
        XCTAssertEqual(resultArray, array.sorted(by: >))
    }
}
