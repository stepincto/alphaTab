// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
#if canImport(Foundation)
import Foundation
#endif

// Hand-written partials: the members the TS marks `@partial` or `@target web`, and the stand-ins for the
// platform pieces the Swift target does not have.

/// The `@partial` members of `Environment` (src/Environment.ts).
internal final class EnvironmentPartials {
    internal static func _createPlatformSpecificRenderEngines(_ engines: Map<String, RenderEngineFactory>) {
        // the Swift target has no engine of its own: SVG is the default
    }

    internal static func _printPlatformInfo(_ print: (String) -> Void) {
        let info = ProcessInfo.processInfo
        print("OS Name: \(info.operatingSystemVersionString)")
        print("Processor Count: \(info.processorCount)")
    }

    internal static func quoteJsonString(_ text: String) -> String {
        // Json.quoteJsonString throws only for a missing escape table entry, which cannot happen
        return try! Json.quoteJsonString(text)
    }

    internal static func sortDescending(_ list: List<Double>) {
        _ = list.sort { (a: Double, b: Double) -> Double in b - a }
    }
}

/// The `@partial` of `FontSizes` (src/platform/svg/FontSizes.ts): measuring a font that has no table.
internal final class FontSizesPartials {
    internal static func generateFontLookup(_ family: String) {
        if FontSizes.fontSizeLookupTables.has(family) {
            return
        }
        // shortcut: the Kotlin target measures through alphaSkia, a browser through a canvas; the Swift target has
        // neither, so a font without a prebuilt table gets the 8x10 box the TS uses under Node. Text in such a font
        // has wrong widths (as in Node); the families alphaTab ships have tables.
        FontSizes.fontSizeLookupTables.set(family, FontSizeDefinition(Uint8Array(List<Double>(8.0)), Uint8Array(List<Double>(10.0))))
    }
}

/// Stand-in for `SkiaCanvas` (src/platform/skia/SkiaCanvas.ts): alphaSkia is a native rasterizer the Swift
/// target does not have. Environment registers the "skia" engine by name, so the type must exist.
internal final class SkiaCanvas: SvgCanvas {
    internal override init() {
        fatalError("The 'skia' render engine (alphaSkia) is not available in Swift; use the 'svg' engine")
    }

    internal static func enable(_ musicFontData: ArrayBuffer, _ alphaSkia: Any?) throws {
        throw JsError("alphaSkia is not available in Swift")
    }

    internal static func registerFont(_ fontData: Uint8Array) throws -> Font {
        throw JsError("alphaSkia is not available in Swift")
    }
}

/// Stand-in for `VersionInfo` (src/generated/VersionInfo.ts): that file is written per build with the build
/// date and git commit, which would change the generated output on every clone.
internal final class VersionInfo {
    internal static let version: String = "1.9.0"
    internal static let date: String = "unknown"
    internal static let commit: String = "unknown"

    internal static func print(_ print: (String) -> Void) {
        print("alphaTab \(VersionInfo.version)")
        print("commit: \(VersionInfo.commit)")
        print("build date: \(VersionInfo.date)")
    }
}

// Element types generated code sizes with `new Array<T>(n)` (see `JsArrayHole`).
extension TabBeatContainerGlyph: JsArrayHole {}
extension Int32Array: JsArrayHole {
    public static var hole: Int32Array { Int32Array(0.0) }
}
extension Spring: JsArrayHole {
    // BarLayoutingInfo.addBeatSpring reads a slot before it writes it and tests it for truthiness
    nonisolated(unsafe) internal static let holeSpring = Spring()
    public static var hole: Spring { holeSpring }
    public var isJsHole: Bool { self === Spring.holeSpring }
}

/// The members the platform layer (`AlphaTabIOS`, a separate module, like the Kotlin target's
/// `alphaTab.platform.android`) needs that the TS marks internal, so the generated code keeps them internal.
public enum PlatformBridge {
    /// Sets one setting by its dotted path (`"player.scrollMode"`) through alphaTab's own settings serializer,
    /// the one `new AlphaTabApi(el, { player: { scrollMode: ... } })` uses. Enums take their number or name.
    public static func setSetting(_ settings: Settings, _ path: String, _ value: Any?) throws {
        let parts = path.split(separator: ".").map(String.init)
        var node: Any? = value
        for key in parts.reversed() {
            let m = Map<String, Any?>()
            m.set(key.lowercased(), node)
            node = m
        }
        try SettingsSerializer.fromJson(settings, node)
    }

    /// The current value at a dotted path, through the same serializer (`toJson`); nil when absent.
    public static func setting(_ settings: Settings, _ path: String) -> Any? {
        guard var node: Any? = try? SettingsSerializer.toJson(settings) else { return nil }
        for key in path.split(separator: ".").map(String.init) {
            guard let m = node as? Map<String, Any?> else { return nil }
            node = m.get(key) ?? m.get(key.lowercased()) ?? nil
        }
        return node
    }

    /// `Environment.highDpiFactor`: the device pixels per point a raster canvas draws at.
    public static var highDpiFactor: Double {
        get { Environment.highDpiFactor }
        set { Environment.highDpiFactor = newValue }
    }

    /// `RenderingResources.smuflFontFamilyName`: the music font a score asks for, nil for the default (Bravura).
    public static func smuflFontFamilyName(_ settings: Settings) -> String? {
        return settings.display.resources.smuflFontFamilyName
    }
}

extension Region: JsArrayHole {
    // `new Array<Region>(n)` slots are read after they are written; a sentinel stands for the hole.
    nonisolated(unsafe) internal static let holeRegion = Region()
    public static var hole: Region { holeRegion }
    public var isJsHole: Bool { self === Region.holeRegion }
}
