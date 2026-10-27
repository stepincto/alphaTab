// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Number`, the members Kotlin's `alphaTab.core.ecmaScript.Number` has.
public enum Number {
    public static let POSITIVE_INFINITY: Double = Double.infinity
    public static let MAX_SAFE_INTEGER: Double = 9_007_199_254_740_991.0
    public static let MIN_SAFE_INTEGER: Double = -9_007_199_254_740_991.0
    public static let NaN: Double = Double.nan

    public static func isNaN(_ d: Double) -> Bool {
        return d.isNaN
    }

    /// JS `parseFloat`: skips leading whitespace, reads the longest numeric prefix, else NaN.
    public static func parseFloat(_ s: String) -> Double {
        let u = Swift.Array(s.utf8)
        var i = 0
        while i < u.count, _isSpace(u[i]) {
            i += 1
        }
        let start = i
        if i < u.count, u[i] == 0x2B || u[i] == 0x2D {
            i += 1
        }
        if u[i...].starts(with: "Infinity".utf8) {
            return u[start] == 0x2D ? -Double.infinity : Double.infinity
        }
        var digits = 0
        while i < u.count, _isDigit(u[i]) {
            i += 1
            digits += 1
        }
        if i < u.count, u[i] == 0x2E {
            i += 1
            while i < u.count, _isDigit(u[i]) {
                i += 1
                digits += 1
            }
        }
        if digits == 0 {
            return Double.nan
        }
        if i < u.count, u[i] == 0x65 || u[i] == 0x45 {
            var j = i + 1
            if j < u.count, u[j] == 0x2B || u[j] == 0x2D {
                j += 1
            }
            if j < u.count, _isDigit(u[j]) {
                while j < u.count, _isDigit(u[j]) {
                    j += 1
                }
                i = j
            }
        }
        return Double(String(decoding: u[start..<i], as: UTF8.self)) ?? Double.nan
    }

    public static func parseInt(_ s: String) -> Double {
        return parseInt(s, 0)
    }

    /// JS `parseInt(s, radix)`: whitespace, sign, `0x` prefix for radix 16 or 0, longest digit prefix.
    public static func parseInt(_ s: String, _ radix: Double) -> Double {
        let u = Swift.Array(s.utf8)
        var i = 0
        while i < u.count, _isSpace(u[i]) {
            i += 1
        }
        var sign = 1.0
        if i < u.count, u[i] == 0x2B || u[i] == 0x2D {
            sign = u[i] == 0x2D ? -1 : 1
            i += 1
        }
        var r = radix.toInt()
        if r != 0 && (r < 2 || r > 36) {
            return Double.nan
        }
        if (r == 0 || r == 16) && i + 1 < u.count && u[i] == 0x30 && (u[i + 1] | 0x20) == 0x78 {
            i += 2
            r = 16
        }
        if r == 0 {
            r = 10
        }
        var value = 0.0
        var any = false
        while i < u.count, let d = _digitValue(u[i]), d < r {
            value = value * Double(r) + Double(d)
            any = true
            i += 1
        }
        return any ? sign * value : Double.nan
    }

    private static func _isDigit(_ c: UInt8) -> Bool {
        return c >= 0x30 && c <= 0x39
    }

    private static func _isSpace(_ c: UInt8) -> Bool {
        return c == 0x20 || (c >= 0x09 && c <= 0x0D)
    }

    private static func _digitValue(_ c: UInt8) -> Int? {
        switch c {
        case 0x30...0x39: return Int(c - 0x30)
        case 0x61...0x7A: return Int(c - 0x61) + 10
        case 0x41...0x5A: return Int(c - 0x41) + 10
        default: return nil
        }
    }
}
