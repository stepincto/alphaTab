// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `String.prototype` semantics (ECMA-262 22.1.3): UTF-16 indices, clamped ranges.
@Suite struct StringTests {
    @Test func substrClampsAndTakesNegativeStart() {
        #expect("abcdef".substr(1, 3) == "bcd")
        #expect("abcdef".substr(4, 10) == "ef")
        #expect("abcdef".substr(-2) == "ef")
        #expect("abcdef".substr(2) == "cdef")
        #expect("abcdef".substr(1, -1) == "")
        #expect("abc".substr(5) == "")
    }

    @Test func substringClampsAndSwaps() {
        #expect("abcdef".substring(1, 3) == "bc")
        #expect("abcdef".substring(3, 1) == "bc")
        #expect("abcdef".substring(-5, 2) == "ab")
        #expect("abcdef".substring(4, 99) == "ef")
        #expect("abcdef".substring(Double.nan, 2) == "ab")
        #expect("abcdef".substring(2) == "cdef")
    }

    @Test func charAtAndCharCodeAtOutOfRange() {
        #expect("abc".charAt(1) == "b")
        #expect("abc".charAt(3) == "")
        #expect("abc"[1.0] == "b")
        #expect("abc".charCodeAt(0) == 97)
        #expect("abc".charCodeAt(5).isNaN)
        // UTF-16 code units, not Characters.
        #expect("\u{1F600}".charCodeAt(0) == 0xD83D)
        #expect("\u{1F600}".length == 2)
    }

    @Test func fromCharCodeWrapsToUint16() {
        #expect(String.fromCharCode(65) == "A")
        #expect(String.fromCharCode(65 + 65536) == "A")
    }

    @Test func splitByReturnsList() {
        let parts: List<String> = "a/b//c".splitBy("/")
        #expect(parts.length == 4)
        #expect(parts.join(",") == "a,b,,c")
        #expect("abc".splitBy("").join(",") == "a,b,c")
        #expect("".splitBy(",").length == 1)
    }

    @Test func indexOfByUtf16() {
        #expect("rgb(1,2)".indexOfInDouble("(") == 3)
        #expect("abc".indexOfInDouble("z") == -1)
        #expect("a(b)c)".lastIndexOfInDouble(")") == 5)
        #expect("abcabc".indexOfInDouble("b", 2) == 4)
        #expect("\u{1F600}x".indexOfInDouble("x") == 2)
    }

    @Test func prefixSuffixAreCodeUnitExact() {
        #expect("#fff".startsWith("#"))
        #expect(!"fff".startsWith("#"))
        #expect("12pt".endsWith("pt"))
        #expect(!"12pt".endsWith("px"))
        // "e" + combining acute is one Character but must not equal a prefix "e" mismatch in JS.
        #expect("e\u{301}x".startsWith("e"))
    }

    @Test func trimLowercaseReplaceAll() {
        #expect("  a b \n\t".trim() == "a b")
        #expect("AbC".lowercase() == "abc")
        #expect("a\"b\"".replaceAll("\"", "\\\"") == "a\\\"b\\\"")
        #expect(true.toString() == "true")
        #expect(false.toString() == "false")
        #expect("k".toString() == "k")
    }

    @Test func fromCodePointBuildsAstralAndBmp() {
        #expect(String.fromCodePoint(65) == "A")
        #expect(String.fromCodePoint(0x1F600) == "\u{1F600}")
        #expect(String.fromCodePoint(0x1F600).length == 2)
        // The lexer spreads a codepoint slice: String.fromCodePoint(...list).
        #expect(String.fromCodePoint(List<Double>(contentsOf: [49, 46, 53])) == "1.5")
        #expect(String.fromCodePoint(List<Double>()) == "")
    }

    @Test func padStartRepeatsAndTruncatesPad() {
        #expect("7".padStart(3, "0") == "007")
        #expect("123".padStart(3, "0") == "123")
        #expect("1234".padStart(3, "0") == "1234")
        #expect("abc".padStart(10, "123") == "1231231abc")
        #expect("abc".padStart(6, "") == "abc")
        #expect("abc".padStart(Double.nan, "0") == "abc")
        #expect("5".padStart(3) == "  5")
    }

    @Test func repeatTruncatesCount() {
        #expect(" ".`repeat`(3) == "   ")
        #expect("ab".`repeat`(2.9) == "abab")
        #expect("ab".`repeat`(0) == "")
        #expect("ab".`repeat`(-0.5) == "")
        #expect("ab".`repeat`(Double.nan) == "")
        #expect("".`repeat`(5) == "")
    }

    @Test func repeatNegativeCountIsRangeError() async {
        await #expect(processExitsWith: .failure) { _ = "a".`repeat`(-1) }
    }

    @Test func repeatInfiniteCountIsRangeError() async {
        await #expect(processExitsWith: .failure) { _ = "a".`repeat`(Double.infinity) }
    }
}

/// `trimEnd`, `replaceAll(regexp, fn)` (values from node).
@Suite struct StringTrimEndAndReplaceTests {
    @Test func trimEndStripsJsWhitespaceOnTheRight() {
        #expect("  a b \t\n\u{00A0}\u{FEFF}".trimEnd() == "  a b")
        #expect("".trimEnd() == "")
        #expect(" \n ".trimEnd() == "")
    }

    @Test func replaceAllWithFunction() {
        #expect("a\"b\\c".replaceAll(RegExp("\"|\\\\", "g"), { (v: String) -> String in "\\" + v }) == "a\\\"b\\\\c")
    }
}

/// `JSON.stringify` of primitives (values from node).
@Suite struct JsonStringifyTests {
    @Test func stringsAreQuotedAndEscaped() {
        #expect(JSON.stringify("a\"b\\c") == "\"a\\\"b\\\\c\"")
        #expect(JSON.stringify("\n\t\u{01}") == "\"\\n\\t\\u0001\"")
        #expect(JSON.stringify("é😀") == "\"é😀\"")
    }

    @Test func otherPrimitives() {
        #expect(JSON.stringify(1.5) == "1.5")
        #expect(JSON.stringify(Double.nan) == "null")
        #expect(JSON.stringify(true) == "true")
        #expect(JSON.stringify(nil) == "null")
    }
}
