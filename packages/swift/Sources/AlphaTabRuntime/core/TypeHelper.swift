// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Port of the parts of Kotlin's `TypeHelper` the generated code calls so far.
/// Not yet ported: `` `in` ``, set/map initializers.
public enum TypeHelper {
    /// `new RegExp(pattern, flags)` and regex literals.
    public static func createRegex(_ pattern: String, _ flags: String) -> RegExp {
        return RegExp(pattern, flags)
    }

    /// JS `typeof`. Closures report "object" (Kotlin does the same).
    public static func typeOf(_ value: Any?) -> String {
        guard let v = unwrapAny(value) else {
            return "undefined"
        }
        switch v {
        case is String:
            return "string"
        case is Bool:
            return "boolean"
        case is Double, is Float, is Int, is Int8, is Int16, is Int32, is Int64,
             is UInt, is UInt8, is UInt16, is UInt32, is UInt64, is any IAlphaTabEnum:
            return "number"
        default:
            return "object"
        }
    }

    /// JS `===` on two `unknown` values: primitives by value (NaN never equal), objects by reference.
    public static func strictEquals(_ a: Any?, _ b: Any?) -> Bool {
        let x = unwrapAny(a)
        let y = unwrapAny(b)
        switch (x, y) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        case let (l as String, r as String):
            return l == r
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        default:
            if typeOf(x) == "number" && typeOf(y) == "number" {
                return unknownToNumber(x) == unknownToNumber(y)
            }
            // only class instances have an identity; other value types are never `===` (as JS objects by value)
            guard let l = x, let r = y, type(of: l) is AnyClass, type(of: r) is AnyClass else {
                return false
            }
            return (l as AnyObject) === (r as AnyObject)
        }
    }

    public static func isTruthy(_ s: String?) -> Bool {
        return s != nil && !s!.isEmpty
    }

    public static func isTruthy(_ b: Bool?) -> Bool {
        return b == true
    }

    public static func isTruthy(_ d: Double) -> Bool {
        return !d.isNaN && d != 0
    }

    public static func isTruthy(_ value: Any?) -> Bool {
        guard let v = unwrapAny(value) else {
            return false
        }
        switch v {
        case let s as String:
            return !s.isEmpty
        case let b as Bool:
            return b
        case let d as Double:
            return isTruthy(d)
        case let i as Int:
            return i != 0
        case let h as any JsArrayHole:
            return !h.isJsHole
        default:
            return true
        }
    }

    /// `value as number` from `unknown`. Traps where Kotlin throws `ClassCastException`:
    /// generated callers carry no `try`.
    public static func unknownToNumber(_ value: Any?) -> Double {
        switch unwrapAny(value) {
        case let d as Double:
            return d
        case let i as Int:
            return Double(i)
        case let e as any IAlphaTabEnum:
            return Double(e.rawValue)
        case nil:
            fatalError("Cannot cast null to number")
        case let v?:
            fatalError("Cannot cast \(type(of: v)) to number")
        }
    }

    /// `value as bigint` from `unknown`. Traps on a non-integer (JS has no implicit number to bigint).
    public static func unknownToInt64(_ value: Any?) -> Int64 {
        switch unwrapAny(value) {
        case let i as Int64:
            return i
        case let i as Int:
            return Int64(i)
        case let v:
            fatalError("Cannot cast \(v.map { "\(type(of: $0))" } ?? "null") to bigint")
        }
    }

    /// `value as T[]` from `unknown`. The same list when it already is a `List<T>`; otherwise (a JSON
    /// list built as `List<T?>` or `List<Any?>`) a copy with each element cast, trapping where an
    /// element is not a `T` (Kotlin's cast throws). shortcut: the copy does not alias the original;
    /// fine for the readers so far (serializers, test helpers), revisit for a caller that mutates it.
    public static func unknownToList<T>(_ value: Any?, _: T.Type) -> List<T> {
        let v = unwrapAny(value)
        if let list = v as? List<T> {
            return list
        }
        guard let list = v as? any _AnyList else {
            fatalError("Cannot cast \(v.map { "\(type(of: $0))" } ?? "null") to List<\(T.self)>")
        }
        return List<T>(contentsOf: list._anyElements.map { $0 as! T })
    }

    /// `value as T[] | null` from `unknown`: nil for null, otherwise as `unknownToList`.
    public static func unknownToNullableList<T>(_ value: Any?, _ type: T.Type) -> List<T>? {
        return unwrapAny(value) == nil ? nil : unknownToList(value, type)
    }

    /// `E[s as keyof typeof E]`, case-insensitive as Kotlin. Traps on an unknown name (Kotlin throws).
    public static func parseEnum<E: IAlphaTabEnum & CaseIterable>(_ value: String, _ type: E.Type) -> E {
        let lower = value.lowercased()
        for e in E.allCases where String(describing: e).lowercased() == lower {
            return e
        }
        fatalError("Could not parse enum value '\(value)'")
    }
}
