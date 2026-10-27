// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `RegExp` and `String.prototype.replace(regexp, ...)` semantics (ECMA-262 22.2, 22.1.3.19).
@Suite struct RegExpTests {
    @Test func globalReplaceReplacesEveryMatch() {
        #expect("A-b c!9".replace(TypeHelper.createRegex("[^a-zA-Z0-9]", "g"), "") == "Abc9")
    }

    @Test func nonGlobalReplaceReplacesFirstMatchOnly() {
        #expect("a&b&c".replace(TypeHelper.createRegex("&", ""), "&amp;") == "a&amp;b&c")
    }

    @Test func replacementPatternsFollowJs() {
        let r = TypeHelper.createRegex("(b)(c)?", "g")
        #expect("abd".replace(r, "[$1|$2|$&|$$|$9]") == "a[b||b|$|$9]d")
        #expect("xbcx".replace(TypeHelper.createRegex("b", ""), "$`$'") == "xxcxcx")
    }

    @Test func ignoreCaseFlag() {
        #expect("AbA".replace(TypeHelper.createRegex("a", "gi"), "x") == "xbx")
    }

    @Test func callbackGetsMatchAndFirstGroup() {
        var seen: [String] = []
        let out = "%TITLE% by %ARTIST%".replace(TypeHelper.createRegex("%([^%]+)%", "g"), { (m: String, g: String) -> String in
            seen.append(m)
            return g.lowercased()
        })
        #expect(out == "title by artist")
        #expect(seen == ["%TITLE%", "%ARTIST%"])
        #expect("ab".replace(TypeHelper.createRegex("[ab]", "g"), { (m: String) -> String in m + m }) == "aabb")
    }

    @Test func testFindsAnywhere() {
        #expect(TypeHelper.createRegex("b+", "").test("abbc"))
        #expect(!TypeHelper.createRegex("^b", "").test("abbc"))
    }

    @Test func utf16AndEmptyMatches() {
        #expect("a\u{1F3B5}b".replace(TypeHelper.createRegex("b", "g"), "c") == "a\u{1F3B5}c")
        #expect("ab".replace(TypeHelper.createRegex("x*", "g"), "-") == "-a-b-")
    }

    @Test func execReturnsMatchAndGroupsOrNull() {
        let m = RegExp("(b+)(x)?c").exec("abbcd")
        #expect(m?.length == 3.0)
        #expect(m?[0] == "bbc")
        #expect(m?[1] == "bb")
        #expect(m?[2] == "")
        #expect(RegExp("z").exec("abc") == nil)
    }
}
