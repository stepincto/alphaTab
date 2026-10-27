// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// JS bit operators on `number`: generated code calls these instead of Swift's
// 64-bit `Int` operators, which neither wrap at 32 bits nor truncate like `x | 0`.

/// ECMA-262 ToUint32: NaN and +-Infinity -> 0, truncate toward zero, modulo 2^32.
@inlinable
public func jsToUint32(_ v: Double) -> UInt32 {
    guard v.isFinite else {
        return 0
    }
    let m = v.rounded(.towardZero).truncatingRemainder(dividingBy: 4_294_967_296)
    return UInt32(m < 0 ? m + 4_294_967_296 : m)
}

/// ECMA-262 ToInt32: ToUint32 read as two's complement.
@inlinable
public func jsToInt32(_ v: Double) -> Int32 {
    return Int32(bitPattern: jsToUint32(v))
}

/// `a & b`
@inlinable
public func jsAnd(_ a: Double, _ b: Double) -> Double {
    return Double(jsToInt32(a) & jsToInt32(b))
}

/// `a | b`; `x | 0` is JS's truncation to int32.
@inlinable
public func jsOr(_ a: Double, _ b: Double) -> Double {
    return Double(jsToInt32(a) | jsToInt32(b))
}

/// `a ^ b`
@inlinable
public func jsXor(_ a: Double, _ b: Double) -> Double {
    return Double(jsToInt32(a) ^ jsToInt32(b))
}

/// `~a`
@inlinable
public func jsNot(_ a: Double) -> Double {
    return Double(~jsToInt32(a))
}

/// `a << b`: the shift count is masked to 5 bits, the result wraps to int32.
@inlinable
public func jsShl(_ a: Double, _ b: Double) -> Double {
    return Double(jsToInt32(a) &<< Int32(jsToUint32(b) & 31))
}

/// `a >> b`: arithmetic shift of the int32 value.
@inlinable
public func jsShr(_ a: Double, _ b: Double) -> Double {
    return Double(jsToInt32(a) &>> Int32(jsToUint32(b) & 31))
}

/// `a >>> b`: logical shift of the uint32 value, an unsigned result.
@inlinable
public func jsUshr(_ a: Double, _ b: Double) -> Double {
    return Double(jsToUint32(a) &>> (jsToUint32(b) & 31))
}
