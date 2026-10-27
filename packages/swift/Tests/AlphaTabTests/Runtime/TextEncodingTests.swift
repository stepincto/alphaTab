// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// WHATWG Encoding semantics for `TextEncoder` / `TextDecoder`: labels are trimmed and
/// case-insensitive, a leading BOM of the decoder's encoding is dropped, invalid input decodes
/// to U+FFFD, and latin1 labels mean windows-1252.
@Suite struct TextEncodingTests {
    private func bytes(_ b: [UInt8]) -> Uint8Array { Uint8Array(b) }

    @Test func encodeIsUtf8() {
        #expect(Swift.Array(TextEncoder().encode("aé\u{1F3B5}")) == [0x61, 0xC3, 0xA9, 0xF0, 0x9F, 0x8E, 0xB5])
    }

    @Test func utf8DropsBomAndReplacesInvalid() {
        #expect(TextDecoder("utf-8").decode(bytes([0xEF, 0xBB, 0xBF, 0x61])) == "a")
        #expect(TextDecoder(" UTF8 ").decode(bytes([0x61, 0xFF, 0x62])) == "a\u{FFFD}b")
    }

    @Test func utf16BothOrdersDropBom() {
        #expect(TextDecoder("utf-16be").decode(bytes([0xFE, 0xFF, 0x00, 0x61, 0x00, 0xE9])) == "aé")
        #expect(TextDecoder("utf-16le").decode(bytes([0xFF, 0xFE, 0x61, 0x00, 0xE9, 0x00])) == "aé")
        #expect(TextDecoder("utf-16").decode(bytes([0x61, 0x00, 0x62])) == "a\u{FFFD}")
    }

    @Test func latin1IsWindows1252() {
        #expect(TextDecoder("ISO-8859-1").decode(bytes([0x41, 0x80, 0x81, 0xE9])) == "A\u{20AC}\u{81}é")
    }

    @Test func decodesSubarrayView() {
        let a = bytes([0x78, 0x61, 0x62, 0x78])
        #expect(TextDecoder("utf-8").decode(a.subarray(1, 3)) == "ab")
    }
}
