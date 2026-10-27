// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `String.prototype` members alphaTab uses (Kotlin's `String.*` partials in `Globals.kt`),
/// with JS semantics: indices are UTF-16 code units, ranges clamp instead of throwing.
/// shortcut: Swift strings cannot hold a lone surrogate, so a slice that splits a surrogate pair
/// becomes U+FFFD; alphaTab only slices ASCII-ish text, revisit if that changes.
extension String {
    @usableFromInline
    internal var _u16: [UInt16] {
        return Swift.Array(self.utf16)
    }

    @usableFromInline
    internal static func _fromU16(_ units: ArraySlice<UInt16>) -> String {
        return String(decoding: units, as: UTF16.self)
    }

    /// ToIntegerOrInfinity clamped to [0, len] (NaN -> 0).
    private static func _clamp(_ d: Double, _ len: Int) -> Int {
        if d.isNaN {
            return 0
        }
        return d <= 0 ? 0 : (d >= Double(len) ? len : Int(d))
    }

    /// Relative start as `substr` / `slice` read it: negative counts from the end.
    private static func _relative(_ d: Double, _ len: Int) -> Int {
        if d.isNaN {
            return 0
        }
        return d < 0 ? Swift.max(len + Int(Swift.max(d, -Double(len))), 0) : String._clamp(d, len)
    }

    public func lowercase() -> String {
        return self.lowercased()
    }

    public func uppercase() -> String {
        return self.uppercased()
    }

    public func toString() -> String {
        return self
    }

    public func substr(_ start: Double, _ length: Double = Double.infinity) -> String {
        let u = self._u16
        let s = String._relative(start, u.count)
        let n = String._clamp(length, u.count - s)
        return String._fromU16(u[s..<(s + n)])
    }

    public func substring(_ start: Double, _ end: Double = Double.infinity) -> String {
        let u = self._u16
        let a = String._clamp(start, u.count)
        let b = String._clamp(end, u.count)
        return String._fromU16(u[Swift.min(a, b)..<Swift.max(a, b)])
    }

    public func charAt(_ index: Double) -> String {
        let u = self._u16
        guard !index.isNaN, index >= 0, index < Double(u.count) else {
            return index.isNaN && !u.isEmpty ? String._fromU16(u[0..<1]) : ""
        }
        let i = Int(index)
        return String._fromU16(u[i..<(i + 1)])
    }

    /// JS `s[i]`: a one-unit string (Kotlin returns a Char); out of range is `""` (JS: undefined).
    public subscript(index: Double) -> String {
        return self.charAt(index)
    }

    public func charCodeAt(_ index: Double) -> Double {
        let u = self._u16
        let i = index.isNaN ? 0 : index
        guard i >= 0, i < Double(u.count) else {
            return Double.nan
        }
        return Double(u[Int(i)])
    }

    public func charCodeAt(_ index: Int) -> Double {
        return self.charCodeAt(Double(index))
    }

    /// `String.fromCharCode(c)`: ToUint16 of the code.
    public static func fromCharCode(_ code: Double) -> String {
        let m = code.isFinite ? code.rounded(.towardZero).truncatingRemainder(dividingBy: 65536) : 0
        return String._fromU16([UInt16(m < 0 ? m + 65536 : m)][...])
    }

    /// `String.fromCodePoint(c)`. shortcut: JS throws RangeError on a non-integer or out-of-range
    /// code and keeps lone surrogates; both become U+FFFD here (call sites cannot `try`, and
    /// Swift strings hold no lone surrogate). alphaTab passes codepoints read from a string.
    public static func fromCodePoint(_ code: Double) -> String {
        let scalar = code == code.rounded(.towardZero) && code >= 0 && code <= 0x10FFFF
            ? Unicode.Scalar(UInt32(code)) : nil
        return String(Character(scalar ?? "\u{FFFD}"))
    }

    /// `String.fromCodePoint(...codes)`: the transpiler passes the spread list as one argument.
    public static func fromCodePoint(_ codes: List<Double>) -> String {
        return codes.map { String.fromCodePoint($0) }.joined()
    }

    /// JS `padStart`: repeats `pad` and truncates it to fill up to `length` UTF-16 units.
    public func padStart(_ length: Double, _ pad: String = " ") -> String {
        let p = pad._u16
        let fill = String._clamp(length, Int.max) - self.utf16.count
        if fill <= 0 || p.isEmpty {
            return self
        }
        return String._fromU16((0..<fill).map { p[$0 % p.count] }[...]) + self
    }

    /// JS `repeat`: count truncated toward zero (NaN -> 0); a negative or infinite count is a
    /// RangeError, which traps here like the typed arrays' range errors.
    public func `repeat`(_ count: Double) -> String {
        let n = count.isNaN ? 0 : count.rounded(.towardZero)
        precondition(n >= 0 && n.isFinite, "RangeError: Invalid count value: \(count)")
        return String(repeating: self, count: Int(n))
    }

    public func splitBy(_ separator: String) -> List<String> {
        let u = self._u16
        let sep = separator._u16
        if sep.isEmpty {
            return List(contentsOf: u.indices.map { String._fromU16(u[$0..<($0 + 1)]) })
        }
        var parts: [String] = []
        var start = 0
        var i = 0
        while i + sep.count <= u.count {
            if u[i..<(i + sep.count)].elementsEqual(sep) {
                parts.append(String._fromU16(u[start..<i]))
                i += sep.count
                start = i
            } else {
                i += 1
            }
        }
        parts.append(String._fromU16(u[start...]))
        return List(contentsOf: parts)
    }

    public func startsWith(_ prefix: String) -> Bool {
        return self.utf16.starts(with: prefix.utf16)
    }

    public func endsWith(_ suffix: String) -> Bool {
        return self.utf16.reversed().starts(with: suffix.utf16.reversed())
    }

    public func indexOfInDouble(_ item: String, _ fromIndex: Double = 0) -> Double {
        let u = self._u16
        let v = item._u16
        var i = String._clamp(fromIndex, u.count)
        while i + v.count <= u.count {
            if u[i..<(i + v.count)].elementsEqual(v) {
                return Double(i)
            }
            i += 1
        }
        return -1
    }

    public func lastIndexOfInDouble(_ item: String) -> Double {
        let u = self._u16
        let v = item._u16
        var i = u.count - v.count
        while i >= 0 {
            if u[i..<(i + v.count)].elementsEqual(v) {
                return Double(i)
            }
            i -= 1
        }
        return -1
    }

    /// JS `trim`: strips WhiteSpace and LineTerminator (ECMA-262 12.2, 12.3).
    public func trim() -> String {
        let u = self._u16
        var a = 0
        var b = u.count
        while a < b, String._isJsSpace(u[a]) {
            a += 1
        }
        while b > a, String._isJsSpace(u[b - 1]) {
            b -= 1
        }
        return String._fromU16(u[a..<b])
    }

    private static func _isJsSpace(_ c: UInt16) -> Bool {
        switch c {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A,
             0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    /// `replaceAll(string, string)`. shortcut: an empty search returns self unchanged (JS inserts
    /// the replacement between every unit); alphaTab never passes one.
    public func replaceAll(_ search: String, _ replacement: String) -> String {
        if search.isEmpty {
            return self
        }
        return self.splitBy(search).join(replacement)
    }
}

extension Bool {
    public func toString() -> String {
        return self ? "true" : "false"
    }
}
