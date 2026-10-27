// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extension Double {
    /// Kotlin's `Double.toInt()`: NaN -> 0, saturating at the bounds (Swift's `Int(x)` traps).
    /// Swift's `Int` is 64-bit where Kotlin's is 32-bit, so it saturates at +-2^63, not +-2^31.
    @inlinable
    public func toInt() -> Int {
        if self.isNaN {
            return 0
        }
        if self >= 9_223_372_036_854_775_807.0 {
            return Int.max
        }
        if self <= -9_223_372_036_854_775_808.0 {
            return Int.min
        }
        return Int(self)
    }

    /// JS `String(n)` (`Number::toString`), used for `"a" + n` and `String(n)`.
    public func toInvariantString() -> String {
        return jsNumberToString(self)
    }

    /// `${n}` in a template literal.
    public func toTemplate() -> String {
        return jsNumberToString(self)
    }
}

extension Int {
    /// Lets generated code write `(i).toInt()` whether `i` is already an `Int` or a `Double`.
    @inlinable
    public func toInt() -> Int {
        return self
    }

    public func toTemplate() -> String {
        return String(self)
    }
}

extension String {
    /// UTF-16 length, as JS.
    public var length: Double {
        return Double(self.utf16.count)
    }

    public func toTemplate() -> String {
        return self
    }
}

extension Bool {
    public func toTemplate() -> String {
        return self ? "true" : "false"
    }
}

extension Optional {
    /// `${x}` for a nullable value: `""` for nil, as Kotlin's `Any?.toTemplate()` (JS prints "null"/"undefined").
    public func toTemplate() -> String {
        return jsTemplate(self)
    }
}

/// `${v}` for a value of unknown static type; also `List.join`.
public func jsTemplate(_ value: Any?) -> String {
    guard let v = unwrapAny(value) else {
        return ""
    }
    switch v {
    case let d as Double:
        return jsNumberToString(d)
    case let s as String:
        return s
    case let b as Bool:
        return b ? "true" : "false"
    case let i as Int:
        return String(i)
    case let e as any IAlphaTabEnum:
        return String(e.rawValue)
    default:
        return String(describing: v)
    }
}

/// Looks through an `Optional` boxed in `Any` (`Any?` holding `Double?.none` is not `nil`).
public func unwrapAny(_ value: Any?) -> Any? {
    guard let v = value else {
        return nil
    }
    let mirror = Mirror(reflecting: v)
    if mirror.displayStyle == .optional {
        return mirror.children.first.map { unwrapAny($0.value) } ?? nil
    }
    return v
}

/// ECMAScript `Number::toString(10)`: `3` not `3.0`, `1e-7`, `1e+21`, `123456789012345680000`.
/// Swift's `description` already gives the shortest round-trip digits, as JS; only the layout differs.
public func jsNumberToString(_ v: Double) -> String {
    if v.isNaN {
        return "NaN"
    }
    if v.isInfinite {
        return v < 0 ? "-Infinity" : "Infinity"
    }
    if v == 0 {
        return "0"
    }
    if v < 0 {
        return "-" + jsNumberToString(-v)
    }
    let text = v.description
    var mantissa = Substring(text)
    var exponent = 0
    if let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        mantissa = text[..<e]
        exponent = Int(text[text.index(after: e)...])!
    }
    var digits: [Character]
    var point: Int
    if let dot = mantissa.firstIndex(of: ".") {
        digits = Swift.Array(mantissa[..<dot]) + Swift.Array(mantissa[mantissa.index(after: dot)...])
        point = mantissa.distance(from: mantissa.startIndex, to: dot)
    } else {
        digits = Swift.Array(mantissa)
        point = digits.count
    }
    while digits.first == "0" {
        digits.removeFirst()
        point -= 1
    }
    while digits.last == "0" {
        digits.removeLast()
    }
    let k = digits.count
    let n = point + exponent
    if k <= n && n <= 21 {
        return String(digits) + String(repeating: "0", count: n - k)
    }
    if 0 < n && n <= 21 {
        return String(digits[..<n]) + "." + String(digits[n...])
    }
    if -6 < n && n <= 0 {
        return "0." + String(repeating: "0", count: -n) + String(digits)
    }
    let e = n - 1
    let m = k == 1 ? String(digits) : String(digits[0]) + "." + String(digits[1...])
    return m + "e" + (e < 0 ? "-" : "+") + String(Swift.abs(e))
}

/// Object literal of a discriminated-union class, Kotlin's `.apply {}`:
/// `with(ShapeCommandCircle()) { $0.kind = "shape.circle" }`.
@discardableResult
public func with<T: AnyObject>(_ obj: T, _ body: (T) throws -> Void) rethrows -> T {
    try body(obj)
    return obj
}

/// `function*` body: `generator { yield in ... yield(x) ... }`.
/// shortcut: runs the body eagerly (Swift has no coroutines); fine for finite generators only,
/// move to a lazy iterator if alphaTab grows an infinite or expensive one.
public func generator<T>(_ body: (_ yield: (T) -> Void) throws -> Void) rethrows -> any IteratorProtocol<T> {
    var items: [T] = []
    try body { items.append($0) }
    return items.makeIterator()
}
