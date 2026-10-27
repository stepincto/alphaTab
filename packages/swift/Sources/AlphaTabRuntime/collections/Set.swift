// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Set<T>`, as Kotlin's `alphaTab.core.ecmaScript.Set`: a reference type that iterates in
/// insertion order. Shadows `Swift.Set` for code that imports AlphaTabRuntime.
/// Elements that are `Hashable` compare by value; other class instances (model types such as
/// `Staff`) compare by identity, as JS does for objects.
public final class Set<T>: Sequence {
    private let _storage = Map<AnyHashable, T>()

    public init() {}

    public init<S: Sequence>(_ values: S?) where S.Element == T {
        if let values {
            for v in values {
                add(v)
            }
        }
    }

    private static func key(_ item: T) -> AnyHashable {
        if let h = item as? AnyHashable {
            return h
        }
        precondition(T.self is AnyClass, "Set element must be Hashable or a class: \(T.self)")
        return ObjectIdentifier(item as AnyObject)
    }

    public var size: Double {
        return _storage.size
    }

    public func add(_ item: T) {
        let k = Self.key(item)
        if !_storage.has(k) {
            _storage.set(k, item)
        }
    }

    public func has(_ item: T) -> Bool {
        return _storage.has(Self.key(item))
    }

    @discardableResult
    public func delete(_ item: T) -> Bool {
        return _storage.delete(Self.key(item))
    }

    public func forEach(_ action: (T) -> Void) {
        for (_, v) in _storage {
            action(v)
        }
    }

    public func clear() {
        _storage.clear()
    }

    public func makeIterator() -> some IteratorProtocol<T> {
        return _storage.lazy.map { $0.1 }.makeIterator()
    }
}
