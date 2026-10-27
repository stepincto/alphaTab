// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Array` statics. This shadows `Swift.Array` for modules that import the runtime,
/// as Kotlin's runtime class does; Swift code there writes `[T]` or `Swift.Array<T>`.
public enum Array {
    public static func from<T>(_ items: some Sequence<T>) -> List<T> {
        return List(contentsOf: items)
    }

    public static func isArray(_ value: Any?) -> Bool {
        guard let v = unwrapAny(value) else {
            return false
        }
        return v is any _AnyList
    }
}

/// Lets `isArray` recognise a `List` of any element type.
public protocol _AnyList {}

extension List: _AnyList {}
