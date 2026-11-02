// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Foundation
import Testing

/// The hand-written `@partial` members of test/TestPlatform.ts (Kotlin's TestPlatformPartialsImpl.kt),
/// only those the generated code calls.
/// JSON as `Any` (objects, arrays, Double, String, Bool, nil), decoded with `JSONDecoder`.
private enum JSONValue: Decodable {
    case number(Double), string(String), bool(Bool), array([JSONValue]), object([String: JSONValue]), null

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    var any: Any? {
        switch self {
        case .number(let v): return v
        case .string(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map { $0.any as Any }
        case .object(let v): return v.mapValues { $0.any as Any }
        case .null: return nil
        }
    }
}

enum TestPlatformPartials {
    /// `packages/alphatab`: vitest runs there, so the tests' relative paths (`test-data/...`) start there.
    private static let projectRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Runtime/
        .deletingLastPathComponent() // AlphaTabTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // swift/
        .deletingLastPathComponent() // packages/
        .appendingPathComponent("alphatab")

    static func resolve(_ path: String) -> URL {
        return path.hasPrefix("/") ? URL(fileURLWithPath: path) : projectRoot.appendingPathComponent(path)
    }

    /// The generated callers carry no `try` (JS rejects the promise), so a missing file traps with its path.
    static func loadFileSync(_ path: String) -> Uint8Array {
        guard let data = try? Data(contentsOf: resolve(path)) else {
            fatalError("TestPlatform.loadFile: cannot read \(resolve(path).path)")
        }
        return Uint8Array([UInt8](data))
    }

    static func loadFile(_ path: String) async -> Uint8Array {
        return loadFileSync(path)
    }

    /// The files (not directories) in `path`, sorted by name: Node's `readdir` order on the file systems
    /// alphaTab's CI uses, and stable across runs.
    static func listDirectory(_ path: String) async -> List<String> {
        let url = resolve(path)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            fatalError("TestPlatform.listDirectory: cannot read \(url.path)")
        }
        let files = names.filter { name in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
        return List<String>(contentsOf: files.sorted())
    }

    private final class Debounce: @unchecked Sendable {
        private let lock = NSLock()
        private var pending: Task<Void, Never>?

        func call(_ action: @escaping () throws -> Void, after delay: Double) {
            nonisolated(unsafe) let action = action
            lock.lock()
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000))
                if !Task.isCancelled {
                    try? action()
                }
            }
            lock.unlock()
        }
    }

    /// Debounce, as Kotlin's `throttle`: every call restarts the delay and only the last one runs.
    static func throttle(_ action: @escaping () throws -> Void, _ delay: Double) -> () -> Void {
        let debounce = Debounce()
        return { debounce.call(action, after: delay) }
    }

    /// `TestPlatform.enumValues(E)`: the numeric members in declaration order, as `Object.values` keeps them.
    static func enumValues<T: CaseIterable>(_ type: T.Type) -> List<T> {
        return List<T>(contentsOf: Swift.Array(T.allCases))
    }

    /// The `it(...)` title of the running test, as the TS `beforeEach` hook stores it.
    static var currentTestName: String {
        return Test.current?.displayName ?? ""
    }

    /// `loadFile` + `JSON.parse`. shortcut: the Kotlin runtime deserializes any `T` by reflection; here only
    /// `SmuflMetadata` (a font's metadata file, the one type the tests load) is built.
    static func loadFileAsJson<T>(_ path: String) async -> T {
        guard T.self == SmuflMetadata.self else {
            fatalError("TestPlatform.loadFileAsJson: only SmuflMetadata is supported, not \(T.self)")
        }
        let data = loadFileSync(path)
        // JSONSerialization parses a fraction through Decimal, one ulp off JS's JSON.parse for some values; the
        // decoder reads Doubles with strtod, which rounds correctly like JS
        guard let root = (try? JSONDecoder().decode(JSONValue.self, from: Data(data.bytes)))?.any as? [String: Any] else {
            fatalError("TestPlatform.loadFileAsJson: \(path) is not a JSON object")
        }
        return parseSmuflMetadata(root) as! T
    }

    private static func point(_ any: Any?) -> (Double, Double)? {
        guard let pair = any as? [Any], pair.count == 2, let x = (pair[0] as? Double),
              let y = (pair[1] as? Double) else {
            return nil
        }
        return (x, y)
    }

    private static func parseSmuflMetadata(_ root: [String: Any]) -> SmuflMetadata {
        let d = root["engravingDefaults"] as? [String: Any] ?? [:]
        func n(_ key: String) -> Double {
            return (d[key] as? Double) ?? 0
        }
        let defaults = SmuflEngravingDefaults(
            arrowShaftThickness: n("arrowShaftThickness"), barlineSeparation: n("barlineSeparation"),
            beamSpacing: n("beamSpacing"), beamThickness: n("beamThickness"), bracketThickness: n("bracketThickness"),
            dashedBarlineDashLength: n("dashedBarlineDashLength"), dashedBarlineGapLength: n("dashedBarlineGapLength"),
            dashedBarlineThickness: n("dashedBarlineThickness"), hairpinThickness: n("hairpinThickness"),
            legerLineExtension: n("legerLineExtension"), legerLineThickness: n("legerLineThickness"),
            lyricLineThickness: n("lyricLineThickness"), octaveLineThickness: n("octaveLineThickness"),
            pedalLineThickness: n("pedalLineThickness"), repeatBarlineDotSeparation: n("repeatBarlineDotSeparation"),
            repeatEndingLineThickness: n("repeatEndingLineThickness"), slurEndpointThickness: n("slurEndpointThickness"),
            slurMidpointThickness: n("slurMidpointThickness"), staffLineThickness: n("staffLineThickness"),
            stemThickness: n("stemThickness"), subBracketThickness: n("subBracketThickness"),
            textEnclosureThickness: n("textEnclosureThickness"), thickBarlineThickness: n("thickBarlineThickness"),
            thinBarlineThickness: n("thinBarlineThickness"), tieEndpointThickness: n("tieEndpointThickness"),
            tieMidpointThickness: n("tieMidpointThickness"), tupletBracketThickness: n("tupletBracketThickness"),
            thinThickBarlineSeparation: (d["thinThickBarlineSeparation"] as? Double)
        )

        let anchors = Record<String, SmuflGlyphWithAnchor>()
        let anchorKeys: [(String, WritableKeyPath<SmuflGlyphWithAnchor, (Double, Double)?>)] = [
            ("splitStemUpSE", \.splitStemUpSE), ("splitStemUpSW", \.splitStemUpSW),
            ("splitStemDownNE", \.splitStemDownNE), ("splitStemDownNW", \.splitStemDownNW),
            ("stemUpSE", \.stemUpSE), ("stemDownNW", \.stemDownNW), ("stemUpNW", \.stemUpNW),
            ("stemDownSW", \.stemDownSW), ("nominalWidth", \.nominalWidth), ("numeralTop", \.numeralTop),
            ("numeralBottom", \.numeralBottom), ("cutOutNE", \.cutOutNE), ("cutOutSE", \.cutOutSE),
            ("cutOutSW", \.cutOutSW), ("cutOutNW", \.cutOutNW), ("graceNoteSlashSW", \.graceNoteSlashSW),
            ("graceNoteSlashNE", \.graceNoteSlashNE), ("graceNoteSlashNW", \.graceNoteSlashNW),
            ("graceNoteSlashSE", \.graceNoteSlashSE), ("repeatOffset", \.repeatOffset),
            ("noteheadOrigin", \.noteheadOrigin), ("opticalCenter", \.opticalCenter)
        ]
        for (name, entry) in (root["glyphsWithAnchors"] as? [String: Any] ?? [:]) {
            var glyph = SmuflGlyphWithAnchor()
            for (key, path) in anchorKeys {
                glyph[keyPath: path] = point((entry as? [String: Any])?[key])
            }
            anchors.set(name, glyph)
        }

        var boxes: Record<String, SmuflGlyphBoundingBox>?
        if let raw = root["glyphBBoxes"] as? [String: Any] {
            boxes = Record<String, SmuflGlyphBoundingBox>()
            for (name, entry) in raw {
                let e = entry as? [String: Any] ?? [:]
                boxes!.set(name, SmuflGlyphBoundingBox(bBoxNE: point(e["bBoxNE"]) ?? (0, 0), bBoxSW: point(e["bBoxSW"]) ?? (0, 0)))
            }
        }
        return SmuflMetadata(engravingDefaults: defaults, glyphsWithAnchors: anchors, glyphBBoxes: boxes)
    }

    static func typedArrayAsUnknownArray(_ array: Any?) -> List<Any?> {
        return List<Any?>(contentsOf: jsElements(array) ?? [])
    }

    static func typedArrayAsUnknownIterable(_ array: Any?) -> any Sequence<Any?> {
        return jsElements(array) ?? []
    }

    static func setAsUnknownIterable(_ set: Any?) -> any Sequence<Any?> {
        return jsElements(set) ?? []
    }

    static func mapAsUnknownIterable(_ map: Any?) -> any Sequence<(Any?, Any?)> {
        return (unwrapAny(map) as? any _AnyMapEntries)?._anyEntries ?? []
    }

    /// JS `val.constructor.name`.
    static func getConstructorName(_ val: Any?) -> String {
        return unwrapAny(val).map { String(describing: type(of: $0)) } ?? "Object"
    }
}
