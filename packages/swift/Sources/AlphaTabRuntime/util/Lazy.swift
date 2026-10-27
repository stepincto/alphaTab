// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Port of `src/util/Lazy.ts` (`@target web`). A computed `nil` is cached, as JS caches `null`.
public final class Lazy<T> {
    private let _factory: () -> T
    private var _value: T?
    public private(set) var hasValue: Bool = false

    public init(_ factory: @escaping () -> T) {
        self._factory = factory
    }

    public var value: T {
        if !hasValue {
            _value = _factory()
            hasValue = true
        }
        return _value!
    }

    public func reset() {
        _value = nil
        hasValue = false
    }
}
