// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Port of `src/util/Lazy.ts` (`@target web`). A computed `nil` is cached, as JS caches `null`.
public final class Lazy<T> {
    private let _factory: () throws -> T
    private var _value: T?
    public private(set) var hasValue: Bool = false

    /// The factory may throw (a TS `x!` or cast in it lowers to a throwing helper).
    public init(_ factory: @escaping () throws -> T) {
        self._factory = factory
    }

    /// `get throws`: a failing factory reaches the reader, as in JS (the emitter prints `try lazy.value`).
    public var value: T {
        get throws {
            if !hasValue {
                _value = try _factory()
                hasValue = true
            }
            return _value!
        }
    }

    public func reset() {
        _value = nil
        hasValue = false
    }
}
