// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extension Int32: TypedArrayElement {
    /// ECMA-262 ToInt32.
    @inlinable public init(js value: Double) { self = jsToInt32(value) }
    @inlinable public var js: Double { Double(self) }
}

/// JS `Int32Array`: values written through ToInt32. Shared core in `Uint8Array.swift`.
public final class Int32Array: TypedArray<Int32> {}
