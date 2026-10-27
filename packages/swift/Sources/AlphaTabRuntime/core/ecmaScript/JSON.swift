// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

/// JS `JSON`.
public enum JSON {
    /// `JSON.stringify` of a primitive: strings quoted with JSON escapes, numbers as JS prints them
    /// (non-finite as `null`), booleans, `null`.
    /// shortcut: objects and arrays trap; add them when a caller stringifies one.
    public static func stringify(_ value: Any?) -> String {
        switch unwrapAny(value) {
        case nil:
            return "null"
        case let s as String:
            return _quote(s)
        case let b as Bool:
            return b ? "true" : "false"
        case let d as Double:
            return d.isFinite ? jsNumberToString(d) : "null"
        case let v?:
            fatalError("JSON.stringify of \(type(of: v)) is not ported")
        }
    }

    /// ECMA-262 QuoteJSONString: `"` `\` and C0 controls escaped, lone surrogates as `\uXXXX`.
    private static func _quote(_ s: String) -> String {
        var out: [UInt16] = [0x22]
        let units = Swift.Array(s.utf16)
        func hex(_ c: UInt16) {
            out.append(contentsOf: "\\u".utf16)
            out.append(contentsOf: String(format: "%04x", c).utf16)
        }
        var i = 0
        while i < units.count {
            let c = units[i]
            switch c {
            case 0x08: out.append(contentsOf: "\\b".utf16)
            case 0x09: out.append(contentsOf: "\\t".utf16)
            case 0x0A: out.append(contentsOf: "\\n".utf16)
            case 0x0C: out.append(contentsOf: "\\f".utf16)
            case 0x0D: out.append(contentsOf: "\\r".utf16)
            case 0x22: out.append(contentsOf: "\\\"".utf16)
            case 0x5C: out.append(contentsOf: "\\\\".utf16)
            case 0..<0x20: hex(c)
            case 0xD800...0xDBFF where i + 1 < units.count && (0xDC00...0xDFFF).contains(units[i + 1]):
                out.append(c)
                out.append(units[i + 1])
                i += 1
            case 0xD800...0xDFFF: hex(c)
            default: out.append(c)
            }
            i += 1
        }
        out.append(0x22)
        return String(decoding: out, as: UTF16.self)
    }
}
