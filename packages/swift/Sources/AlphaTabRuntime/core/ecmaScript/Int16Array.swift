// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extension Int16: TypedArrayElement {
    /// ECMA-262 ToInt16: ToInt32 modulo 2^16.
    @inlinable public init(js value: Double) { self.init(truncatingIfNeeded: jsToInt32(value)) }
    @inlinable public var js: Double { Double(self) }
}

extension UInt16: TypedArrayElement {
    /// ECMA-262 ToUint16: ToUint32 modulo 2^16.
    @inlinable public init(js value: Double) { self.init(truncatingIfNeeded: jsToUint32(value)) }
    @inlinable public var js: Double { Double(self) }
}

extension UInt32: TypedArrayElement {
    /// ECMA-262 ToUint32.
    @inlinable public init(js value: Double) { self = jsToUint32(value) }
    @inlinable public var js: Double { Double(self) }
}

/// JS `Int16Array`. Shared core in `Uint8Array.swift`.
public final class Int16Array: TypedArray<Int16> {}

/// JS `Uint16Array`.
public final class Uint16Array: TypedArray<UInt16> {}

/// JS `Uint32Array`.
public final class Uint32Array: TypedArray<UInt32> {}
