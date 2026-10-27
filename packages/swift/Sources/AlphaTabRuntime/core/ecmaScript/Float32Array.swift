// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extension Float: TypedArrayElement {
    /// Round to nearest single precision (ECMA-262 `ToFloat32`, `Math.fround`).
    @inlinable public init(js value: Double) { self.init(value) }
    @inlinable public var js: Double { Double(self) }
}

/// JS `Float32Array`. Shared core in `Uint8Array.swift`.
public final class Float32Array: TypedArray<Float> {}
