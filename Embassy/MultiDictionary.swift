//
//  MultiDictionary.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 6/1/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Transform for MultiDictionary keys, like lower case
public protocol KeyTransformType {
    associatedtype Key: Hashable
    static func transform(key: Key) -> Key
}

/// A key transform that does nothing to the key but simply return it
public struct NoOpKeyTransform<T: Hashable>: KeyTransformType {
    public typealias Key = T
    public static func transform(key: T) -> NoOpKeyTransform.Key {
        return key
    }
}

/// A key transform that lower case of the String key, so that the MultiDictionary will be
/// case-insenstive
public struct LowercaseKeyTransform: KeyTransformType {
    public typealias Key = String
    public static func transform(key: Key) -> LowercaseKeyTransform.Key {
        return key.lowercaseString
    }
}

/// MultiDictionary is a Dictionary and Array like container, it allows one key to have multiple
/// values
public struct MultiDictionary<
    Key: Hashable,
    Value,
    KeyTransform: KeyTransformType
    where KeyTransform.Key == Key
> {
    typealias ArrayType = Array<(Key, Value)>
    typealias DictionaryType = Dictionary<Key, Array<Value>>

    // Items in this multi dictionary
    private let items: ArrayType
    // Dictionary mapping from key to tuple of original key (before transform) and all values in
    /// order
    private let keyValuesMap: DictionaryType

    public init(items: Array<(Key, Value)>) {
        self.items = items
        var keyValuesMap: DictionaryType = [:]
        for (key, value) in items {
            let transformedKey = KeyTransform.transform(key)
            var values = keyValuesMap[transformedKey] ?? []
            values.append(value)
            keyValuesMap[transformedKey] = values
        }
        self.keyValuesMap = keyValuesMap
    }

    /// Get all values for given key in occurrence order
    ///  - Parameter key: the key
    ///  - Returns: tuple of array of values for given key
    public func valuesFor(key: Key) -> Array<Value>? {
        return keyValuesMap[KeyTransform.transform(key)]
    }
    /// Get the first value for given key if available
    ///  - Parameter key: the key
    ///  - Returns: first value for the key if available, otherwise nil will be returned
    public subscript(key: Key) -> Value? {
        return valuesFor(key)?.first
    }
}

// MARK: Indexable
extension MultiDictionary: Indexable {
    public typealias Index = ArrayType.Index
    public var startIndex: MultiDictionary.Index {
        return items.startIndex
    }
    public var endIndex: MultiDictionary.Index {
        return items.endIndex
    }
}

// MARK: CollectionType
extension MultiDictionary: CollectionType {
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
}

// MARK: ArrayLiteralConvertible
extension MultiDictionary: ArrayLiteralConvertible {
    public typealias Element = ArrayType.Element
    public init(arrayLiteral elements: MultiDictionary.Element...) {
        items = elements
        var keyValuesMap: DictionaryType = [:]
        for (key, value) in items {
            let transformedKey = KeyTransform.transform(key)
            var values = keyValuesMap[transformedKey] ?? []
            values.append(value)
            keyValuesMap[transformedKey] = values
        }
        self.keyValuesMap = keyValuesMap
    }
}
