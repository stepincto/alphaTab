// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Testing

/// JS semantics of `JsonHelper.parseEnum`, `forEach` and `getValue` (src/io/JsonHelper.ts).
@Suite struct JsonHelperPartialsTests {
    @Test func parseEnumByNameIgnoresCase() {
        #expect(JsonHelperPartials.parseEnum("italic", FontStyle.self) == .Italic)
        #expect(JsonHelperPartials.parseEnum("ITALIC", FontStyle.self) == .Italic)
        #expect(JsonHelperPartials.parseEnum("nope", FontStyle.self) == nil)
    }

    @Test func parseEnumNumericStringUsesParseInt() {
        // JS: Number.parseInt(s, 10), so a leading number wins ("1px" -> 1).
        #expect(JsonHelperPartials.parseEnum("1", FontStyle.self) == .Italic)
        #expect(JsonHelperPartials.parseEnum("1px", FontStyle.self) == .Italic)
    }

    @Test func parseEnumNumbersAndMissing() {
        #expect(JsonHelperPartials.parseEnum(1.0, FontStyle.self) == .Italic)
        #expect(JsonHelperPartials.parseEnum(0, FontStyle.self) == .Plain)
        #expect(JsonHelperPartials.parseEnum(FontStyle.Italic, FontStyle.self) == .Italic)
        #expect(JsonHelperPartials.parseEnum(nil, FontStyle.self) == nil)
        #expect(JsonHelperPartials.parseEnum(Map<String, Any?>(), FontStyle.self) == nil)
    }

    @Test func forEachVisitsMapInOrder() {
        let m = Map<String, Any?>()
        m.set("b", 1.0)
        m.set("a", "x")
        var keys: [String] = []
        JsonHelperPartials.forEach(m, { (_: Any?, k: String) in keys.append(k) })
        #expect(keys == ["b", "a"])
        var count = 0
        JsonHelperPartials.forEach(m, { (_: Any?, _: String) -> Bool in
            count += 1
            return true
        })
        #expect(count == 2)
        JsonHelperPartials.forEach(nil, { (_: Any?, _: String) in count += 1 })
        #expect(count == 2)
        // a multi-statement closure without a return type is the TS `=> void` callback (generated deserializers)
        JsonHelperPartials.forEach(m, { (_: Any?, k: String) in
            switch k {
            case "a":
                count += 10
            default:
                break
            }
        })
        #expect(count == 12)
    }

    @Test func getValueReadsMapKeys() {
        let m = Map<String, Any?>()
        m.set("tick", 5.0)
        let optional: Any? = m
        #expect(JsonHelperPartials.getValue(optional, "tick") as? Double == 5.0)
        #expect(JsonHelperPartials.getValue(m, "missing") == nil)
        #expect(JsonHelperPartials.getValue(3.0, "tick") == nil)
    }
}
