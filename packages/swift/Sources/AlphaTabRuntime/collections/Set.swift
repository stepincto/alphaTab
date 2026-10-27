// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Set<T>`, as Kotlin's `alphaTab.core.ecmaScript.Set`: a reference type that iterates in
/// insertion order. Shadows `Swift.Set` for code that imports AlphaTabRuntime.
public final class Set<T: Hashable>: Sequence {
    private let _storage = Map<T, Bool>()

    public init() {}

    public init<S: Sequence>(_ values: S?) where S.Element == T {
        if let values {
            for v in values {
                add(v)
            }
        }
    }

    public var size: Double {
        return _storage.size
    }

    public func add(_ item: T) {
        _storage.set(item, true)
    }

    public func has(_ item: T) -> Bool {
        return _storage.has(item)
    }

    @discardableResult
    public func delete(_ item: T) -> Bool {
        return _storage.delete(item)
    }

    public func forEach(_ action: (T) -> Void) {
        for (k, _) in _storage {
            action(k)
        }
    }

    public func clear() {
        _storage.clear()
    }

    public func makeIterator() -> some IteratorProtocol<T> {
        return _storage.lazy.map { $0.0 }.makeIterator()
    }
}
