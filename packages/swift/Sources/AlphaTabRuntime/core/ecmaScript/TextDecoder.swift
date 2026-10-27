// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `TextDecoder` for the encodings alphaTab files use: UTF-8, UTF-16LE/BE and
/// windows-1252 (which WHATWG also uses for latin1 / iso-8859-1 / ascii labels). As in JS,
/// a leading BOM of the decoder's own encoding is dropped and invalid input becomes U+FFFD.
/// An unknown label is a RangeError in JS; it traps here, like the typed arrays' range errors.
public final class TextDecoder {
    private enum Kind { case utf8, utf16le, utf16be, windows1252 }
    private let kind: Kind

    public init(_ label: String = "utf-8") {
        // WHATWG strips leading and trailing ASCII whitespace from a label.
        let ws = { (c: Character) in c.isASCII && c.isWhitespace }
        switch String(label.drop(while: ws).reversed().drop(while: ws).reversed()).lowercased() {
        case "utf-8", "utf8", "unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "x-unicode20utf8":
            kind = .utf8
        case "utf-16le", "utf-16", "ucs-2", "unicode", "csunicode", "iso-10646-ucs-2", "unicodefeff":
            kind = .utf16le
        case "utf-16be", "unicodefffe":
            kind = .utf16be
        case "windows-1252", "cp1252", "x-cp1252", "latin1", "l1", "iso-8859-1", "iso8859-1", "iso88591",
             "iso_8859-1", "iso_8859-1:1987", "iso-ir-100", "ibm819", "cp819", "csisolatin1",
             "ascii", "us-ascii", "ansi_x3.4-1968", "csascii":
            kind = .windows1252
        default:
            fatalError("RangeError: The encoding label provided ('\(label)') is invalid.")
        }
    }

    public func decode(_ buffer: Uint8Array) -> String {
        let bytes = buffer.storage.data[buffer.offset ..< buffer.offset + buffer.count]
        switch kind {
        case .utf8:
            let body = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? bytes.dropFirst(3) : bytes
            return String(decoding: body, as: UTF8.self)
        case .utf16le, .utf16be:
            let le = kind == .utf16le
            var units = [UInt16]()
            units.reserveCapacity(bytes.count / 2)
            var i = bytes.startIndex
            while i + 1 < bytes.endIndex {
                let a = UInt16(bytes[i]), b = UInt16(bytes[i + 1])
                units.append(le ? a | b << 8 : a << 8 | b)
                i += 2
            }
            if units.first == 0xFEFF { units.removeFirst() }
            // An odd trailing byte is an incomplete code unit: one U+FFFD, as in JS.
            return String(decoding: units, as: UTF16.self) + (bytes.count % 2 == 1 ? "\u{FFFD}" : "")
        case .windows1252:
            return String(String.UnicodeScalarView(bytes.map { b in
                Unicode.Scalar(b >= 0x80 && b < 0xA0 ? TextDecoder.cp1252High[Int(b) - 0x80] : UInt16(b))!
            }))
        }
    }

    /// windows-1252 0x80-0x9F (WHATWG index); undefined slots map to the C1 control itself.
    private static let cp1252High: [UInt16] = [
        0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
        0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
    ]
}
