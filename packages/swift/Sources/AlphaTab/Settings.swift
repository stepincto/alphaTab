// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: until the filter drops. A hand-written stand-in for src/Settings.ts with only the members
// the tier-"model" and "io-alphatex" code names (its import closure is the whole library, see scripts/transpile.ts).
// Delete this file, and SettingsSerializer.swift, when the filter takes in Settings.

/// Stand-in for `Settings` (src/Settings.ts).
public final class Settings {
    public var core: CoreSettings = CoreSettings()
    public var display: DisplaySettings = DisplaySettings()
    public var notation: NotationSettings = NotationSettings()
    public var importer: ImporterSettings = ImporterSettings()
    public var exporter: ExporterSettings = ExporterSettings()

    public init() {}
}

/// Stand-in for `ExporterSettings` (src/ExporterSettings.ts).
public final class ExporterSettings {
    public var indent: Double = 2.0
    public var comments: Bool = false

    public init() {}
}

/// Stand-in for `ImporterSettings` (src/ImporterSettings.ts).
public final class ImporterSettings {
    public var encoding: String = "utf-8"
    public var gp3To5encoding: String = "windows-1252"
    public var mergePartGroupsInMusicXml: Bool = false
    public var beatTextAsLyrics: Bool = false
    public var maxDecodingBufferSize: Double = 128000000.0

    public init() {}
}

/// Stand-in for `CoreSettings` (src/CoreSettings.ts).
public final class CoreSettings {
    public var enableLazyLoading: Bool = true
    public var logLevel: LogLevel = LogLevel.Info

    public init() {}
}

/// Stand-in for `DisplaySettings` (src/DisplaySettings.ts).
public final class DisplaySettings {
    public var scale: Double = 1.0
    public var layoutMode: LayoutMode = LayoutMode.Page
    public var startBar: Double = 1.0
    public var barCount: Double = -1.0
    public var resources: RenderingResources = RenderingResources()

    public init() {}
}

/// Stand-in for `RenderingResources` (src/RenderingResources.ts).
public final class RenderingResources {
    public var engravingSettings: EngravingSettings = EngravingSettings()
    public var mainGlyphColor: Color = Color(0.0, 0.0, 0.0, 255.0)

    public init() {}
}

/// Stand-in for `EngravingSettings` (src/EngravingSettings.ts).
public final class EngravingSettings {
    public init() {}

    // shortcut: no SMuFL metadata yet, so every symbol counts as present (JS: width and height > 0 in
    // the Bravura defaults); upgrade when EngravingSettings is generated with its metadata.
    public func hasSymbol(_ symbol: MusicFontSymbol) -> Bool {
        return true
    }
}

/// Stand-in for `Environment` (src/Environment.ts) with the members the io-alphatex tier names; the real
/// one reaches the whole library (importers, renderers, workers).
public final class Environment {
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

/// Stand-in for `ScoreLoader` (src/importer/ScoreLoader.ts): only `loadAlphaTex`, the rest needs
/// Environment's importer list.
public final class ScoreLoader {
    public static func loadAlphaTex(_ tex: String, _ settings: Settings? = nil) throws -> Score {
        let parser = AlphaTexImporter()
        parser.logErrors = true
        parser.initFromString(tex, settings ?? Settings())
        return try parser.readScore()
    }
}
