// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Foundation

// Hand-written stand-in for test/visualTests/VisualTestHelper.ts: that file draws with alphaSkia and compares
// PNGs, which the Swift target cannot do (it renders SVG). The members the tests call keep their names.

final class VisualTestRun {
    var width: Double
    var referenceFileName: String

    init(_ width: Double, _ referenceFileName: String) {
        self.width = width == -1 ? 1300 : width
        self.referenceFileName = referenceFileName
    }
}

/// Stand-in for alphaSkia's `AlphaSkiaCanvas`, the raster canvas the TS tests draw debug overlays on (bounds
/// lookups, skylines) before comparing PNGs. It draws nothing: the SVG goldens cover the score, the overlay
/// code still runs against the rendered result, but the overlay pixels are not compared (see SKIPPED.md).
final class AlphaSkiaCanvas {
    var color: Double = 0
    var lineWidth: Double = 1

    static func rgbaToColor(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Double {
        return Double((Int(a) << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b))
    }

    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {}
    func strokeRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {}
}

final class VisualTestOptions {
    var score: Score
    var runs: List<VisualTestRun>
    var settings: Settings
    var tracks: List<Double>?
    var tolerancePercent: Double?
    var prepareFullImage: ((VisualTestRun, AlphaTabApiBase<Any?>, AlphaSkiaCanvas) throws -> Void)?

    init(_ score: Score, _ runs: List<VisualTestRun>, _ settings: Settings?) {
        self.score = score
        self.runs = runs
        self.settings = settings ?? Settings()
    }

    static func file(_ inputFile: String, _ runs: List<VisualTestRun>, _ settings: Settings? = nil) async throws -> VisualTestOptions {
        let inputFileData = await TestPlatformPartials.loadFile("test-data/visual-tests/\(inputFile)")
        let score = try ScoreLoader.loadScoreFromBytes(inputFileData, settings)
        return VisualTestOptions(score, runs, settings)
    }

    static func tex(_ tex: String, _ referenceFileName: String, _ settings: Settings? = nil) throws -> VisualTestOptions {
        let settings = settings ?? Settings()
        let importer = AlphaTexImporter()
        importer.`init`(ByteBuffer.fromString(tex), settings)
        let score = try importer.readScore()
        return VisualTestOptions(score, List<VisualTestRun>(VisualTestRun(1300, referenceFileName)), settings)
    }
}

enum VisualTestHelper {
    /// alphaSkia needs its fonts and music font loaded; the SVG engine needs nothing.
    static func prepareAlphaSkia() async throws {
    }

    /// As the TS: scale 1 and Noto font families, so the text of the SVG matches the TS goldens. The TS sets the
    /// `skia` engine here; the Swift target renders the same scores with `svg`.
    static func prepareSettingsForTest(_ settings: Settings) {
        settings.core.engine = "svg"
        Environment.highDpiFactor = 1
        settings.core.enableLazyLoading = false

        settings.display.resources.tablatureFont.families = List<String>("Noto Sans", "Noto Music", "Noto Color Emoji")
        settings.display.resources.graceFont.families = List<String>("Noto Sans", "Noto Music", "Noto Color Emoji")
        settings.display.resources.numberedNotationFont.families = List<String>("Noto Sans", "Noto Music", "Noto Color Emoji")
        settings.display.resources.numberedNotationGraceFont.families = List<String>("Noto Sans", "Noto Music", "Noto Color Emoji")

        for f in settings.display.resources.elementFonts.values() {
            if f.families.includes("sans-serif") {
                f.families = List<String>("Noto Sans", "Noto Music", "Noto Color Emoji")
            } else {
                f.families = List<String>("Noto Serif", "Noto Music", "Noto Color Emoji")
            }
        }
    }

    static func runVisualTest(
        _ inputFile: String,
        _ settings: Settings? = nil,
        _ configure: ((VisualTestOptions) throws -> Void)? = nil
    ) async throws {
        let inputFile = "test-data/visual-tests/\(inputFile)"
        let inputFileData = await TestPlatformPartials.loadFile(inputFile)
        let referenceFileName = TestPlatform.changeExtension(inputFile, ".png")
        let score = try ScoreLoader.loadScoreFromBytes(inputFileData, settings)
        let options = VisualTestOptions(score, List<VisualTestRun>(VisualTestRun(-1, referenceFileName)), settings)
        try configure?(options)
        try await runVisualTestFull(options)
    }

    static func runVisualTestTex(
        _ tex: String,
        _ referenceFileName: String,
        _ settings: Settings? = nil,
        _ configure: ((VisualTestOptions) throws -> Void)? = nil
    ) async throws {
        let options = try VisualTestOptions.tex(tex, referenceFileName, settings)
        try configure?(options)
        try await runVisualTestFull(options)
    }

    /// Renders every run with the SVG engine and compares the text with the golden the TS wrote
    /// (scripts/svg-goldens/SvgGoldenHelper.ts renders the same options through the TS original).
    static func runVisualTestFull(_ options: VisualTestOptions) async throws {
        let settings = options.settings
        let tracks = options.tracks ?? List<Double>(0.0)
        let runs = options.runs
        var runIndex = 0

        prepareSettingsForTest(settings)

        var results: [[RenderFinishedEventArgs]] = []
        var totalWidths: [Double] = []
        var totalHeights: [Double] = []
        let uiFacade = TestUiFacade()
        uiFacade.rootContainer.width = runs[runIndex].width
        runIndex += 1

        let api = try AlphaTabApiBase<Any?>(uiFacade, settings)
        defer {
            try? api.destroy()
        }

        let timeout = 2000.0 * runs.length
        try await TypeHelper.createPromise({ (resolve: @escaping () -> Void, reject: @escaping (Any) -> Void) in
            api.renderStarted.on({ (_: Bool) in
                results.append([])
                totalWidths.append(0)
                totalHeights.append(0)
            })
            try api.renderer.partialRenderFinished.on({ (e: RenderFinishedEventArgs) in
                results[results.count - 1].append(e)
            })
            try api.renderer.renderFinished.on({ (e: RenderFinishedEventArgs) in
                totalWidths[totalWidths.count - 1] = e.totalWidth
                totalHeights[totalHeights.count - 1] = e.totalHeight
                results[results.count - 1].append(e)
            })
            try api.renderer.postRenderFinished.on({ () in
                if runIndex < runs.length.toInt() {
                    uiFacade.rootContainer.width = runs[runIndex].width
                    runIndex += 1
                    try api.triggerResize()
                } else {
                    resolve()
                }
            })
            api.error.on({ (e: JsError) in
                reject(JsError("Failed to render image (\(e.message) \(e.stack()))", e))
            })

            // as the TS: the score goes through the serializer once, so both sides render the same objects
            // the render ids (`class="b12"`) count up from the last import: start from zero, as the TS helper does
            Score.resetIds()
            let renderScore = try JsonConverter.jsObjectToScore(JsonConverter.scoreToJsObject(options.score), settings)
            try api.renderScore(renderScore, tracks)
            Globals.setTimeout({ () in
                reject(JsError("Rendering did not complete after \(timeout)ms"))
            }, timeout)
        })

        var failures: [String] = []
        for i in 0..<results.count {
            try options.prepareFullImage?(runs[i], api, AlphaSkiaCanvas())
            let actual = goldenText(totalWidths[i], totalHeights[i], results[i])
            if let failure = SvgGolden.compare(actual, runs[i].referenceFileName) {
                failures.append(failure)
            }
        }
        if !failures.isEmpty {
            throw JsError(failures.joined(separator: "\n"))
        }
    }

    /// The text the TS `goldenText` writes: the size line, then a header line and the SVG per partial result.
    static func goldenText(_ totalWidth: Double, _ totalHeight: Double, _ result: [RenderFinishedEventArgs]) -> String {
        var text = "total \(totalWidth.toTemplate()) \(totalHeight.toTemplate())\n"
        for partial in result {
            text += "partial \(partial.x.toTemplate()) \(partial.y.toTemplate()) \(partial.width.toTemplate()) \(partial.height.toTemplate())\n"
            // `${null}`: the last event of a render has no result
            text += "\(partial.renderResult == nil ? "null" : jsTemplate(partial.renderResult))\n"
        }
        return text
    }
}

enum SvgGolden {
    /// `Tests/AlphaTabTests/SvgGoldens`, written by `npm run svg-goldens` from the TS original, never from Swift.
    private static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Runtime/
        .deletingLastPathComponent() // AlphaTabTests/
        .appendingPathComponent("SvgGoldens")

    /// `test-data/visual-tests/layout/foo.png` -> `layout/foo.svg.txt`
    static func name(_ referenceFileName: String) -> String {
        var name = referenceFileName.replacingOccurrences(of: "\\", with: "/")
        if name.hasPrefix("test-data/visual-tests/") {
            name = String(name.dropFirst("test-data/visual-tests/".count))
        }
        if name.hasSuffix(".png") {
            name = String(name.dropLast(4))
        }
        return name + ".svg.txt"
    }

    /// Every decimal number with a fraction part (`-12.3456`, `0.1234e-5`) rounded to 2 decimals and printed as
    /// `%.2f` (`-0.00` as `0.00`). Integers (ids, code points, sizes) and everything else stay as they are.
    static func normalized(_ text: String) -> String {
        let number = try! NSRegularExpression(pattern: "-?[0-9]+\\.[0-9]+(?:e[+-]?[0-9]+)?")
        let ns = text as NSString
        var out = ""
        var last = 0
        for match in number.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let value = Double(ns.substring(with: match.range)) ?? 0
            let rounded = String(format: "%.2f", value)
            out += rounded == "-0.00" ? "0.00" : rounded
            last = match.range.location + match.range.length
        }
        return out + ns.substring(from: last)
    }

    /// nil when the SVG equals the golden, else why not.
    static func compare(_ actual: String, _ referenceFileName: String) -> String? {
        let name = name(referenceFileName)
        // SVG_ACTUAL_DIR=/tmp/x keeps what Swift rendered next to the same names, for a diff against the golden
        if let dir = ProcessInfo.processInfo.environment["SVG_ACTUAL_DIR"] {
            let out = URL(fileURLWithPath: dir).appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? actual.write(to: out, atomically: true, encoding: .utf8)
        }
        let file = root.appendingPathComponent(name)
        guard let expected = try? String(contentsOf: file, encoding: .utf8) else {
            return "Missing SVG golden \(name); generate it from the TS with `npm run svg-goldens`"
        }
        // one golden holds every distinct rendering of a reference image that several tests name
        let alternatives = expected.components(separatedBy: "\n--- another test renders the same reference image ---\n")
        if alternatives.contains(actual) {
            return nil
        }
        // shortcut: V8 computes sin, cos, pow and atan2 with its own fdlibm port and glibc rounds differently
        // in the last bit, so a curve coordinate can differ by one ulp. Such a pair is accepted when both texts
        // are equal after every decimal number is rounded to 2 decimals (see `normalized`).
        let normalizedActual = normalized(actual)
        if alternatives.contains(where: { normalized($0) == normalizedActual }) {
            print("note: \(name) equals its golden only after rounding numbers to 2 decimals")
            return nil
        }
        let a = Swift.Array(actual.utf8)
        let e = Swift.Array((alternatives.first ?? "").utf8)
        var i = 0
        while i < a.count && i < e.count && a[i] == e[i] {
            i += 1
        }
        func excerpt(_ bytes: [UInt8]) -> String {
            let from = max(0, i - 80)
            return String(decoding: bytes[from..<min(bytes.count, i + 120)], as: UTF8.self)
        }
        return "SVG differs from golden \(name) at byte \(i) (actual \(a.count) bytes, golden \(e.count) bytes)\n  golden: \(excerpt(e))\n  actual: \(excerpt(a))"
    }
}
