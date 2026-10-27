// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: src/Environment.ts reaches the whole library (renderers, synth, workers), so it stays out of
// the transpile filter; this stand-in has only the members the generated code names. Delete it when the
// filter takes in Environment.

/// Stand-in for `Environment` (src/Environment.ts).
public final class Environment {
    /// JS `Environment.buildImporters`, same importers in the same order.
    public static func buildImporters() -> List<ScoreImporter> {
        return List<ScoreImporter>(
            Gp3To5Importer(),
            GpxImporter(),
            Gp7To8Importer(),
            MusicXmlImporter(),
            CapellaImporter(),
            AlphaTexImporter()
        )
    }

    /// JS `JSON.stringify(text)` for a string (ECMA-262 QuoteJSONString), UTF-16 like JS: lone
    /// surrogates come out as `\uXXXX`.
    public static func quoteJsonString(_ text: String) -> String {
        var out: [UInt16] = [0x22]
        let units = Swift.Array(text.utf16)
        func hex(_ u: UInt16) {
            out.append(contentsOf: String(format: "\\u%04x", u).utf16)
        }
        var i = 0
        while i < units.count {
            let u = units[i]
            switch u {
            case 0x22: out.append(contentsOf: "\\\"".utf16)
            case 0x5C: out.append(contentsOf: "\\\\".utf16)
            case 0x08: out.append(contentsOf: "\\b".utf16)
            case 0x0C: out.append(contentsOf: "\\f".utf16)
            case 0x0A: out.append(contentsOf: "\\n".utf16)
            case 0x0D: out.append(contentsOf: "\\r".utf16)
            case 0x09: out.append(contentsOf: "\\t".utf16)
            case 0xD800...0xDBFF where i + 1 < units.count && (0xDC00...0xDFFF).contains(units[i + 1]):
                out.append(u)
                out.append(units[i + 1])
                i += 1
            case 0..<0x20, 0xD800...0xDFFF: hex(u)
            default: out.append(u)
            }
            i += 1
        }
        out.append(0x22)
        return String(decoding: out, as: UTF16.self)
    }
}
