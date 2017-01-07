//
//  SelectSelector.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 1/6/17.
//  Copyright © 2017 Fang-Pen Lin. All rights reserved.
//

import Foundation

public final class SelectSelector: Selector {

    public init(selectMaximumEvent: Int = 1024) throws {
        // TODO:
    }

    public func register(_ fileDescriptor: Int32, events: Set<IOEvent>, data: Any?) throws -> SelectorKey {
        // TODO:
        return SelectorKey(fileDescriptor: 0, events: [], data: nil)
    }

    public func unregister(_ fileDescriptor: Int32) throws -> SelectorKey {
        // TODO:
        return SelectorKey(fileDescriptor: 0, events: [], data: nil)
    }

    public func close() {
        // TODO:
    }

    public func select(timeout: TimeInterval?) throws -> [(SelectorKey, Set<IOEvent>)] {
        // TODO:
        return []
    }

    public subscript(fileDescriptor: Int32) -> SelectorKey? {
        // TODO:
        return nil
    }
}
