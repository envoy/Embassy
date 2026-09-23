//
//  HeapSortTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/25/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Testing

@testable import Embassy

@Suite struct HeapSortTests {
    @Test func push() {
        var heap: [Int] = []

        HeapSort.heapPush(&heap, item: 100)
        #expect(heap == [100])

        HeapSort.heapPush(&heap, item: 50)
        #expect(heap == [50, 100])

        HeapSort.heapPush(&heap, item: 25)
        #expect(heap == [25, 100, 50])

        HeapSort.heapPush(&heap, item: 49)
        #expect(heap == [25, 49, 50, 100])

        HeapSort.heapPush(&heap, item: 51)
        #expect(heap == [25, 49, 50, 100, 51])

        HeapSort.heapPush(&heap, item: 52)
        #expect(heap == [25, 49, 50, 100, 51, 52])

        HeapSort.heapPush(&heap, item: 48)
        #expect(heap == [25, 49, 48, 100, 51, 52, 50])
    }

    @Test func pop() {
        var heap = [25, 49, 48, 100, 51, 52, 50]

        #expect(HeapSort.heapPop(&heap) == 25)
        #expect(heap == [48, 49, 50, 100, 51, 52])

        #expect(HeapSort.heapPop(&heap) == 48)
        #expect(heap == [49, 51, 50, 100, 52])

        #expect(HeapSort.heapPop(&heap) == 49)
        #expect(heap == [50, 51, 52, 100])

        #expect(HeapSort.heapPop(&heap) == 50)
        #expect(heap == [51, 100, 52])

        #expect(HeapSort.heapPop(&heap) == 51)
        #expect(heap == [52, 100])

        #expect(HeapSort.heapPop(&heap) == 52)
        #expect(heap == [100])

        #expect(HeapSort.heapPop(&heap) == 100)
        #expect(heap == [])
    }

    @Test func sortWithRandomNumbers() {
        let array = (0..<100).map { _ in UInt32.random(in: .min ... .max) }
        var heap: [UInt32] = []
        for num in array {
            HeapSort.heapPush(&heap, item: num)
        }
        var result: [UInt32] = []
        while !heap.isEmpty {
            result.append(HeapSort.heapPop(&heap))
        }
        #expect(result == array.sorted())
    }

    @Test func sortWithRandomNumbersWithCustomCompareFunction() {
        let array = (0..<100).map { _ in UInt32.random(in: .min ... .max) }
        var heap: [UInt32] = []
        for num in array {
            HeapSort.heapPush(&heap, item: num, isOrderredBefore: >)
        }
        var result: [UInt32] = []
        while !heap.isEmpty {
            result.append(HeapSort.heapPop(&heap, isOrderredBefore: >))
        }
        #expect(result == array.sorted(by: >))
    }
}
