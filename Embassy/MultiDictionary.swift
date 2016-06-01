//
//  MultiDictionary.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/1/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// MultiDictionary is a Dictionary like container, but allow one key to have multiple values
public struct MultiDictionary<Key: Hashable, Value>: CollectionType, ArrayLiteralConvertible {
    typealias ArrayType = Array<(Key, Value)>
    // Items in this multi dictionary
    private let items: ArrayType
    // Dictionary mapping from key to all values in order
    private let keyValuesMap: Dictionary<Key, Array<Value>>

    // MARK: Indexable
    public typealias Index = ArrayType.Index
    public var startIndex: MultiDictionary.Index {
        return items.startIndex
    }
    public var endIndex: MultiDictionary.Index {
        return items.endIndex
    }
    // MARK: CollectionType
    public typealias Generator = ArrayType.Generator
    public typealias SubSequence = ArrayType.SubSequence
    public func generate() -> MultiDictionary.Generator {
        return items.generate()
    }
    public subscript (position: MultiDictionary.Index) -> MultiDictionary.Generator.Element {
        return items[position]
    }
    public subscript (bounds: Range<MultiDictionary.Index>) -> MultiDictionary.SubSequence {
        return items[bounds]
    }
    public func prefixUpTo(end: MultiDictionary.Index) -> MultiDictionary.SubSequence {
        return items.prefixUpTo(end)
    }
    public func suffixFrom(start: MultiDictionary.Index) -> MultiDictionary.SubSequence {
        return items.suffixFrom(start)
    }
    public func prefixThrough(position: MultiDictionary.Index) -> MultiDictionary.SubSequence {
        return items.prefixThrough(position)
    }
    public var isEmpty: Bool {
        return items.isEmpty
    }
    public var count: MultiDictionary.Index.Distance {
        return items.count
    }
    public var first: MultiDictionary.Generator.Element? {
        return items.first
    }
    // MARK: ArrayLiteralConvertible
    public typealias Element = ArrayType.Element
    public init(arrayLiteral elements: MultiDictionary.Element...) {
        items = elements
        var keyValuesMap: Dictionary<Key, Array<Value>> = [:]
        for (key, value) in elements {
            var values = keyValuesMap[key] ?? []
            values.append(value)
            keyValuesMap[key] = values
        }
        self.keyValuesMap = keyValuesMap
    }

    // MARK: MultiDictionary
    public init(items: Array<(Key, Value)>) {
        self.items = items
        var keyValuesMap: Dictionary<Key, Array<Value>> = [:]
        for (key, value) in items {
            var values = keyValuesMap[key] ?? []
            values.append(value)
            keyValuesMap[key] = values
        }
        self.keyValuesMap = keyValuesMap
    }

    /// Get all values for given key in occurrence order
    ///  - Parameter key: the key
    ///  - Returns: array of values for given key
    public func valuesFor(key: Key) -> Array<Value>? {
        return keyValuesMap[key]
    }

    /// Get the first value for given key if available
    ///  - Parameter key: the key
    ///  - Returns: first value for the key if available, otherwise nil will be returned
    public subscript(key: Key) -> Value? {
        return valuesFor(key)?.first
    }
}
