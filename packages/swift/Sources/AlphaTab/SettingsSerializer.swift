// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: until the filter drops. Hand-written stand-in for src/generated/SettingsSerializer.ts and
// the Core/Display/RenderingResources/NotationSettings serializers, covering only the members in
// Settings.swift. Same key rules as JS: keys are lower-cased, and a group's members also match with
// the group name as prefix ("displayLayoutMode") or, for core and display, with no prefix.
internal final class SettingsSerializer {
    public static func fromJson(_ obj: Settings, _ m: Any?) throws {
        if !TypeHelper.isTruthy(m) {
            return
        }
        try JsonHelperPartials.forEach(m, { (v: Any?, k: String) -> Bool in
            return try SettingsSerializer.setProperty(obj, k.lowercased(), v)
        })
    }

    public static func toJson(_ obj: Settings?) -> Map<String, Any?>? {
        guard let obj = obj else {
            return nil
        }
        let o: Map<String, Any?> = Map<String, Any?>()
        let core: Map<String, Any?> = Map<String, Any?>()
        core.set("enablelazyloading", obj.core.enableLazyLoading)
        core.set("loglevel", Double(obj.core.logLevel.rawValue))
        o.set("core", core)
        let resources: Map<String, Any?> = Map<String, Any?>()
        resources.set("mainglyphcolor", Color.toJson(obj.display.resources.mainGlyphColor))
        let display: Map<String, Any?> = Map<String, Any?>()
        display.set("scale", obj.display.scale)
        display.set("layoutmode", Double(obj.display.layoutMode.rawValue))
        display.set("startbar", obj.display.startBar)
        display.set("barcount", obj.display.barCount)
        display.set("resources", resources)
        o.set("display", display)
        let notation: Map<String, Any?> = Map<String, Any?>()
        notation.set("notationmode", Double(obj.notation.notationMode.rawValue))
        notation.set("rhythmmode", Double(obj.notation.rhythmMode.rawValue))
        notation.set("transpositionpitches", obj.notation.transpositionPitches)
        notation.set("displaytranspositionpitches", obj.notation.displayTranspositionPitches)
        o.set("notation", notation)
        return o
    }

    public static func setProperty(_ obj: Settings, _ property: String, _ v: Any?) throws -> Bool {
        if try group(property, v, ["core", ""], { try setCore(obj.core, $0, $1) }) {
            return true
        }
        if try group(property, v, ["display", ""], { try setDisplay(obj.display, $0, $1) }) {
            return true
        }
        return try group(property, v, ["notation"], { try setNotation(obj.notation, $0, $1) })
    }

    /// One JS group block: the bare group key fills the whole group, otherwise each prefix is stripped
    /// and the rest is tried as a member.
    private static func group(_ property: String, _ v: Any?, _ prefixes: [String], _ set: (String, Any?) throws -> Bool) throws -> Bool {
        if prefixes.contains(property) {
            try JsonHelperPartials.forEach(v, { (v: Any?, k: String) -> Bool in
                return try set(k.lowercased(), v)
            })
            return true
        }
        for c in prefixes where property.hasPrefix(c) {
            if try set(String(property.dropFirst(c.count)), v) {
                return true
            }
        }
        return false
    }

    private static func setCore(_ obj: CoreSettings, _ property: String, _ v: Any?) throws -> Bool {
        switch property {
        case "enablelazyloading":
            obj.enableLazyLoading = v as! Bool
            return true
        case "loglevel":
            obj.logLevel = JsonHelperPartials.parseEnum(v, LogLevel.self)!
            return true
        default:
            return false
        }
    }

    private static func setDisplay(_ obj: DisplaySettings, _ property: String, _ v: Any?) throws -> Bool {
        switch property {
        case "scale":
            obj.scale = v as! Double
            return true
        case "layoutmode":
            obj.layoutMode = JsonHelperPartials.parseEnum(v, LayoutMode.self)!
            return true
        case "startbar":
            obj.startBar = v as! Double
            return true
        case "barcount":
            obj.barCount = v as! Double
            return true
        case "resources":
            try JsonHelperPartials.forEach(v, { (v: Any?, k: String) -> Bool in
                return try setResources(obj.resources, k.lowercased(), v)
            })
            return true
        default:
            break
        }
        // JS: DisplaySettingsSerializer tries "resources" as a prefix too ("resourcesMainGlyphColor").
        if property.hasPrefix("resources") {
            return try setResources(obj.resources, String(property.dropFirst("resources".count)), v)
        }
        return false
    }

    private static func setResources(_ obj: RenderingResources, _ property: String, _ v: Any?) throws -> Bool {
        switch property {
        case "mainglyphcolor":
            obj.mainGlyphColor = try Color.fromJson(v)!
            return true
        default:
            return false
        }
    }

    private static func setNotation(_ obj: NotationSettings, _ property: String, _ v: Any?) throws -> Bool {
        switch property {
        case "notationmode":
            obj.notationMode = JsonHelperPartials.parseEnum(v, NotationMode.self)!
            return true
        case "rhythmmode":
            obj.rhythmMode = JsonHelperPartials.parseEnum(v, TabRhythmMode.self)!
            return true
        case "transpositionpitches":
            obj.transpositionPitches = v as! List<Double>
            return true
        case "displaytranspositionpitches":
            obj.displayTranspositionPitches = v as! List<Double>
            return true
        default:
            return false
        }
    }
}
