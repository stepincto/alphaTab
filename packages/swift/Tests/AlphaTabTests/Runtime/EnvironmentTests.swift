// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Testing
@testable import AlphaTab
import AlphaTabRuntime

/// `Json.quoteJsonString` (what `EnvironmentPartials.quoteJsonString` calls) is JS `JSON.stringify(string)`
/// (ECMA-262 25.5.2.3 QuoteJSONString), `ScoreLoader.loadAlphaTex` reads alphaTex like JS.
@Suite struct EnvironmentTests {
    @Test func quoteJsonStringEscapesLikeJsonStringify() {
        #expect(EnvironmentPartials.quoteJsonString("a\"b\\c") == "\"a\\\"b\\\\c\"")
        #expect(EnvironmentPartials.quoteJsonString("\n\r\t\u{08}\u{0C}") == "\"\\n\\r\\t\\b\\f\"")
        #expect(EnvironmentPartials.quoteJsonString("\u{01}\u{1F}/\u{7F}") == "\"\\u0001\\u001f/\u{7F}\"")
        #expect(EnvironmentPartials.quoteJsonString("\u{1F3B5}é") == "\"\u{1F3B5}é\"")
    }

    @Test func exporterSettingsDefaults() {
        let s = Settings()
        #expect(s.exporter.indent == 2.0)
        #expect(s.exporter.comments == false)
    }

    @Test func loadAlphaTexReadsAScore() throws {
        let score = try ScoreLoader.loadAlphaTex("\\title \"T\" . 3.3 4.3 | 5.3.2")
        #expect(score.title == "T")
        #expect(score.masterBars.length == 2.0)
    }
}
