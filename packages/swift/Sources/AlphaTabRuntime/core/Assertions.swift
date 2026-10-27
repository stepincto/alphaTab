// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// TS `x!` and `x as T` where they can fail at run time (the emitter decides, `SwiftThrows.isThrowingAssertion`).
// JS throws a TypeError where the value is then used, Kotlin and C# throw at the unwrap or cast;
// Swift's `!` and `as!` would trap the whole process, so these throw a catchable `JsError` instead.

/// `x!`: the value, or throws when it is nil (Kotlin's `!!` NullPointerException).
@inlinable
public func jsNonNull<T>(_ value: T?) throws -> T {
    guard let value else {
        throw JsError("Cannot unwrap a null or undefined \(T.self)")
    }
    return value
}

/// `x as T` that may fail: the value as a `T`, or throws (Kotlin's ClassCastException, C#'s InvalidCastException).
@inlinable
public func jsCast<T>(_ value: Any?, _ type: T.Type) throws -> T {
    guard let cast = value as? T else {
        throw JsError("Cannot cast \(value.map { String(describing: Swift.type(of: $0)) } ?? "nil") to \(T.self)")
    }
    return cast
}
