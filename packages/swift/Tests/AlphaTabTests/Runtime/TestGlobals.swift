// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// Port of Kotlin's `TestGlobals`: generated tests call `TestGlobals.expect(a).toBe(b)`.
/// Each failure is recorded as a Swift Testing issue at the generated test's line, with the
/// matcher, expected and received values, as vitest prints them.
/// Not ported: snapshots (`toMatchSnapshot`), chai's `assert` class.
public enum TestGlobals {
    public static func expect<T>(
        _ actual: T,
        _ message: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Expector<T> {
        return Expector(actual, message, false, sourceLocation)
    }

    /// `expect(() => f()).toThrow()`.
    public static func expect(
        _ actual: @escaping () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Expector<() throws -> Void> {
        return Expector(actual, nil, false, sourceLocation)
    }

    /// `expect(() => new X()).toThrow()`: the closure's value is dropped, as JS does.
    public static func expect<R>(
        _ actual: @escaping () throws -> R,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Expector<() throws -> Void> {
        return Expector({ _ = try actual() }, nil, false, sourceLocation)
    }

    public static func fail(_ message: Any?, sourceLocation: SourceLocation = #_sourceLocation) {
        Issue.record(Comment(rawValue: jsTemplate(message)), sourceLocation: sourceLocation)
    }
}

/// vitest's `expect(actual)` chain. `.not()` (a call, as Kotlin's) flips every check (Kotlin's separate `NotExpector`).
public final class Expector<T> {
    private let _actual: T
    private let _message: String?
    private let _negated: Bool
    private let _location: SourceLocation

    init(_ actual: T, _ message: String?, _ negated: Bool, _ location: SourceLocation) {
        _actual = actual
        _message = message
        _negated = negated
        _location = location
    }

    public func not() -> Expector<T> {
        return Expector(_actual, _message, !_negated, _location)
    }

    /// vitest `toBe` (Object.is), except `-0` equals `0` as in Kotlin's port. Numbers compare by
    /// value across `Int`/`Double` (`toBe(0)` passes `Any?` an `Int`), class instances by identity.
    public func toBe(_ expected: Any?) {
        _check(jsSame(_actual, expected), "toBe", jsDescribe(expected))
    }

    /// vitest `toEqual`: deep, element-wise for lists and field-wise for records.
    public func toEqual(_ expected: Any?, _ message: String? = nil) {
        _check(jsDeepEqual(_actual, expected), "toEqual", jsDescribe(expected), message)
    }

    /// vitest: `|expected - actual| < 10^-numDigits / 2`.
    public func toBeCloseTo(_ expected: Double, _ numDigits: Double = 2) {
        guard let a = _number(_actual) else {
            return _check(false, "toBeCloseTo", "a number close to \(jsDescribe(expected))")
        }
        let pass = a == expected || Swift.abs(expected - a) < Math.pow(10, -numDigits) / 2
        _check(pass, "toBeCloseTo", "\(jsDescribe(expected)) (\(jsDescribe(numDigits)) digits)")
    }

    public func toBeGreaterThan(_ expected: Double, _ message: String? = nil) {
        _compare(expected, "toBeGreaterThan", "> ", message) { $0 > $1 }
    }

    public func toBeGreaterThanOrEqual(_ expected: Double, _ message: String? = nil) {
        _compare(expected, "toBeGreaterThanOrEqual", ">= ", message) { $0 >= $1 }
    }

    public func toBeLessThan(_ expected: Double, _ message: String? = nil) {
        _compare(expected, "toBeLessThan", "< ", message) { $0 < $1 }
    }

    public func toBeLessThanOrEqual(_ expected: Double, _ message: String? = nil) {
        _compare(expected, "toBeLessThanOrEqual", "<= ", message) { $0 <= $1 }
    }

    public func toBeTruthy() {
        _check(TypeHelper.isTruthy(_actual as Any?), "toBeTruthy", "truthy")
    }

    public func toBeFalsy() {
        _check(!TypeHelper.isTruthy(_actual as Any?), "toBeFalsy", "falsy")
    }

    public func toBeNull() {
        _check(unwrapAny(_actual) == nil, "toBeNull", "null")
    }

    public func toBeUndefined() {
        _check(unwrapAny(_actual) == nil, "toBeUndefined", "undefined")
    }

    public func toBeInstanceOf<U>(_ type: U.Type) {
        _check(unwrapAny(_actual) is U, "toBeInstanceOf", "an instance of \(U.self)")
    }

    /// Substring for strings, element (`toBe` equality) for lists and other sequences.
    public func toContain(_ value: Any?) {
        let pass: Bool
        if let s = unwrapAny(_actual) as? String, let sub = value as? String {
            pass = sub.isEmpty || s.contains(sub)
        } else if let items = jsElements(_actual) {
            pass = items.contains { jsSame($0, value) }
        } else {
            pass = false
        }
        _check(pass, "toContain", jsDescribe(value))
    }

    public func toHaveLength(_ expected: Double) {
        let length: Double?
        if let s = unwrapAny(_actual) as? String {
            length = s.length
        } else {
            length = jsElements(_actual).map { Double($0.count) }
        }
        _check(length == expected, "toHaveLength", "length \(jsDescribe(expected))", received: "length \(length.map(jsDescribe) ?? "none")")
    }

    /// `actual` must be a closure (`TestGlobals.expect({ ... })`); passes when it throws,
    /// and when `type` is given, throws that type or a subclass.
    public func toThrow(_ type: (any Swift.Error.Type)? = nil) {
        guard let body = _actual as? () throws -> Void else {
            return _check(false, "toThrow", "a function")
        }
        do {
            try body()
            _check(false, "toThrow", "an error", received: "no error")
        } catch {
            _check(type.map { _isError(error, $0) } ?? true, "toThrow", type.map { "\($0)" } ?? "an error", received: "threw \(Swift.type(of: error))")
        }
    }

    private func _isError<E: Swift.Error>(_ error: any Swift.Error, _ type: E.Type) -> Bool {
        return error is E
    }

    private func _compare(_ expected: Double, _ matcher: String, _ op: String, _ message: String?, _ cmp: (Double, Double) -> Bool) {
        guard let a = _number(_actual) else {
            return _check(false, matcher, "a number \(op)\(jsDescribe(expected))", message)
        }
        _check(cmp(a, expected), matcher, op + jsDescribe(expected), message)
    }

    /// Records a vitest-style failure: the matcher, then expected and received values.
    private func _check(_ pass: Bool, _ matcher: String, _ expected: String, _ message: String? = nil, received: String? = nil) {
        if pass != _negated {
            return
        }
        let not = _negated ? "not." : ""
        var text = "expect(received).\(not)\(matcher)(expected)\nExpected: \(_negated ? "not " : "")\(expected)\nReceived: \(received ?? jsDescribe(_actual))"
        if let note = _message ?? message {
            text = "\(note): " + text
        }
        Issue.record(Comment(rawValue: text), sourceLocation: _location)
    }
}

/// Any numeric value (including an enum's raw value) as a Double, else nil.
private func _number(_ value: Any?) -> Double? {
    switch unwrapAny(value) {
    case let d as Double: return d
    case let f as Float: return Double(f)
    case let i as Int: return Double(i)
    case let i as Int32: return Double(i)
    case let e as any IAlphaTabEnum: return Double(e.rawValue)
    default: return nil
    }
}

/// vitest `toBe` with Kotlin's `-0 == 0` leniency: NaN is NaN, objects by identity.
public func jsSame(_ a: Any?, _ b: Any?) -> Bool {
    let ua = unwrapAny(a)
    let ub = unwrapAny(b)
    guard let x = ua, let y = ub else {
        return ua == nil && ub == nil
    }
    if let nx = _number(x), let ny = _number(y) {
        return nx == ny || (nx.isNaN && ny.isNaN)
    }
    if type(of: x) is AnyClass && type(of: y) is AnyClass {
        return (x as AnyObject) === (y as AnyObject)
    }
    if let hx = x as? AnyHashable, let hy = y as? AnyHashable {
        return hx == hy
    }
    return false
}

/// vitest `toEqual`: lists element-wise, class/struct instances field-wise (via `Mirror`).
/// shortcut: no cycle detection; add one if a test compares self-referencing graphs.
public func jsDeepEqual(_ a: Any?, _ b: Any?) -> Bool {
    if jsSame(a, b) {
        return true
    }
    guard let x = unwrapAny(a), let y = unwrapAny(b) else {
        return false
    }
    if x is String || y is String || _number(x) != nil || _number(y) != nil {
        return false
    }
    if let ex = jsElements(x), let ey = jsElements(y) {
        return ex.count == ey.count && zip(ex, ey).allSatisfy { jsDeepEqual($0, $1) }
    }
    guard type(of: x) == type(of: y) else {
        return false
    }
    let fx = Swift.Array(Mirror(reflecting: x).children)
    let fy = Swift.Array(Mirror(reflecting: y).children)
    return fx.count == fy.count && zip(fx, fy).allSatisfy { $0.label == $1.label && jsDeepEqual($0.value, $1.value) }
}

/// The elements of a list or other non-string sequence, else nil.
public func jsElements(_ value: Any?) -> [Any?]? {
    guard let v = unwrapAny(value), !(v is String), let seq = v as? any Sequence else {
        return nil
    }
    return _elements(seq)
}

private func _elements(_ seq: some Sequence) -> [Any?] {
    return seq.map { $0 }
}

/// How a value reads in a failure message: JS number formatting, quoted strings.
public func jsDescribe(_ value: Any?) -> String {
    guard let v = unwrapAny(value) else {
        return "null"
    }
    if let s = v as? String {
        return "\"\(s)\""
    }
    if let items = jsElements(v) {
        return "[" + items.map(jsDescribe).joined(separator: ", ") + "]"
    }
    return jsTemplate(v)
}
