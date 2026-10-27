// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// One key/value pair, as Kotlin's `alphaTab.collections.MapEntry`.
public final class MapEntry<TKey, TValue> {
    public internal(set) var key: TKey
    public internal(set) var value: TValue

    public init(_ key: TKey, _ value: TValue) {
        self.key = key
        self.value = value
    }
}

/// JS `Map<K, V>`: iterates in insertion order; `set` on an existing key keeps its place.
/// Kotlin's `ObjectDoubleMap` and friends collapse into this. `Hashable` keys compare by value;
/// other class instances (model types such as `Staff`) compare by identity, as JS does for objects.
/// shortcut: mutating a Map while iterating it is undefined here (JS defines it); handle it if a caller does it.
open class Map<TKey, TValue>: Sequence {
    private var _index: [AnyHashable: Int] = [:]
    private var _entries: [MapEntry<TKey, TValue>?] = []
    private var _holes: Int = 0

    public init() {}

    public init(_ entries: (TKey, TValue)...) {
        for (k, v) in entries {
            set(k, v)
        }
    }

    /// `new Map([[k, v], ...])`: the generated code passes the array literal as an array of tuples.
    public init<S: Sequence>(_ entries: S) where S.Element == (TKey, TValue) {
        for (k, v) in entries {
            set(k, v)
        }
    }

    public init(_ other: Map<TKey, TValue>) {
        for (k, v) in other {
            set(k, v)
        }
    }

    private static func key(_ key: TKey) -> AnyHashable {
        if let h = key as? AnyHashable {
            return h
        }
        precondition(TKey.self is AnyClass, "Map key must be Hashable or a class: \(TKey.self)")
        return ObjectIdentifier(key as AnyObject)
    }

    public var size: Double {
        return Double(_index.count)
    }

    public func has(_ key: TKey) -> Bool {
        return _index[Self.key(key)] != nil
    }

    public func get(_ key: TKey) -> TValue? {
        guard let i = _index[Self.key(key)] else {
            return nil
        }
        return _entries[i]!.value
    }

    public func set(_ key: TKey, _ value: TValue) {
        let k = Self.key(key)
        if let i = _index[k] {
            _entries[i]!.value = value
        } else {
            _index[k] = _entries.count
            _entries.append(MapEntry(key, value))
        }
    }

    @discardableResult
    public func delete(_ key: TKey) -> Bool {
        guard let i = _index.removeValue(forKey: Self.key(key)) else {
            return false
        }
        _entries[i] = nil
        _holes += 1
        if _holes > 16 && _holes * 2 > _entries.count {
            _compact()
        }
        return true
    }

    public func clear() {
        _index.removeAll()
        _entries.removeAll()
        _holes = 0
    }

    public func keys() -> List<TKey> {
        return List(contentsOf: _entries.lazy.compactMap { $0?.key })
    }

    public func values() -> List<TValue> {
        return List(contentsOf: _entries.lazy.compactMap { $0?.value })
    }

    /// JS `entries()`: `(key, value)` tuples in insertion order (a snapshot, not a live iterator).
    public func entries() -> List<(TKey, TValue)> {
        return List(contentsOf: self)
    }

    /// Yields `(key, value)` tuples, as JS yields `[key, value]` arrays, so `for (k, v) in m` destructures.
    public func makeIterator() -> some IteratorProtocol<(TKey, TValue)> {
        return _entries.lazy.compactMap { $0.map { ($0.key, $0.value) } }.makeIterator()
    }

    private func _compact() {
        _entries = _entries.filter { $0 != nil }
        for (i, e) in _entries.enumerated() {
            _index[Self.key(e!.key)] = i
        }
        _holes = 0
    }
}
