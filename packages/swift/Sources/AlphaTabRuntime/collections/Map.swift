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
/// Kotlin's `ObjectDoubleMap` and friends collapse into this. Keys must be `Hashable`.
/// shortcut: mutating a Map while iterating it is undefined here (JS defines it); handle it if a caller does it.
open class Map<TKey: Hashable, TValue>: Sequence {
    private var _index: [TKey: Int] = [:]
    private var _entries: [MapEntry<TKey, TValue>?] = []
    private var _holes: Int = 0

    public init() {}

    public init(_ entries: (TKey, TValue)...) {
        for (k, v) in entries {
            set(k, v)
        }
    }

    public init(_ other: Map<TKey, TValue>) {
        for e in other {
            set(e.key, e.value)
        }
    }

    public var size: Double {
        return Double(_index.count)
    }

    public func has(_ key: TKey) -> Bool {
        return _index[key] != nil
    }

    public func get(_ key: TKey) -> TValue? {
        guard let i = _index[key] else {
            return nil
        }
        return _entries[i]!.value
    }

    public func set(_ key: TKey, _ value: TValue) {
        if let i = _index[key] {
            _entries[i]!.value = value
        } else {
            _index[key] = _entries.count
            _entries.append(MapEntry(key, value))
        }
    }

    @discardableResult
    public func delete(_ key: TKey) -> Bool {
        guard let i = _index.removeValue(forKey: key) else {
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

    public func makeIterator() -> some IteratorProtocol<MapEntry<TKey, TValue>> {
        return _entries.lazy.compactMap { $0 }.makeIterator()
    }

    private func _compact() {
        _entries = _entries.filter { $0 != nil }
        for (i, e) in _entries.enumerated() {
            _index[e!.key] = i
        }
        _holes = 0
    }
}
