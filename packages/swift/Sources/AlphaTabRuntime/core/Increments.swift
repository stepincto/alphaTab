// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// `x++` and friends used as a value (Swift has no `++`): generated code passes the operand `inout`.
// As a statement the emitter prints `x += 1` instead.

/// `x++`: increments, returns the old value.
@inlinable @discardableResult
public func jsPostInc<T: Numeric>(_ x: inout T) -> T {
    let old = x
    x += 1
    return old
}

/// `++x`: increments, returns the new value.
@inlinable @discardableResult
public func jsPreInc<T: Numeric>(_ x: inout T) -> T {
    x += 1
    return x
}

/// `x--`: decrements, returns the old value.
@inlinable @discardableResult
public func jsPostDec<T: Numeric>(_ x: inout T) -> T {
    let old = x
    x -= 1
    return old
}

/// `--x`: decrements, returns the new value.
@inlinable @discardableResult
public func jsPreDec<T: Numeric>(_ x: inout T) -> T {
    x -= 1
    return x
}
