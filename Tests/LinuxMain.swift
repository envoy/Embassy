import XCTest
@testable import EmbassyTests

XCTMain([
    testCase(HeapSortTetsts.allTests),
    testCase(HTTPHeaderParserTests.allTests),
    testCase(MultiDictionaryTests.allTests),
    testCase(TCPSocketTests.allTests),
    testCase(SelectSelectorTests.allTests),
])
