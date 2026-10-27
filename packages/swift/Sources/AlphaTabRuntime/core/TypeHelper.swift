// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Port of the parts of Kotlin's `TypeHelper` the generated code calls so far.
/// Not yet ported: `createPromise`, `` `in` ``, set/map initializers.
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

    /// `E[s as keyof typeof E]`, case-insensitive as Kotlin. Traps on an unknown name (Kotlin throws).
    public static func parseEnum<E: IAlphaTabEnum & CaseIterable>(_ value: String, _ type: E.Type) -> E {
        let lower = value.lowercased()
        for e in E.allCases where String(describing: e).lowercased() == lower {
            return e
        }
        fatalError("Could not parse enum value '\(value)'")
    }
}
