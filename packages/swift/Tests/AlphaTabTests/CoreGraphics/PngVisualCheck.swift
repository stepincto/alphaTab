// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#if canImport(CoreGraphics) && canImport(CoreText)
@testable import AlphaTab
import AlphaTabIOS
import AlphaTabRuntime
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The PNG half of the TS `VisualTestHelper` (`compareVisualResult`, `_expectToEqualVisuallyAsync`), on the Core
/// Graphics engine: each visual test's runs are drawn with `CoreGraphicsCanvas`, overlays included, and compared
/// with the TS reference PNG (drawn by alphaSkia) through the translated `PixelMatch` with the TS options
/// (threshold 0.3, anti-aliasing ignored, the test's `tolerancePercent`, 0 by default).
///
/// Every case writes a line to `packages/swift/.visual-png/results.tsv` (gitignored); a case outside tolerance
/// also writes `<reference>.new.png` and `<reference>.diff.png` there. The SVG golden stays the test's
/// pass/fail; it runs only with `ALPHATAB_PNG_CHECK=1` (reports) or `ALPHATAB_PNG_STRICT=1` (fails on a mismatch), because Core Text and alphaSkia's
/// FreeType do not rasterize glyphs to the same pixels (see SKIPPED.md).
enum PngVisualCheck {
    /// `packages/swift/.visual-png`
    static let outputDir: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CoreGraphics/
        .deletingLastPathComponent() // AlphaTabTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // swift/
        .appendingPathComponent(".visual-png")

    static var resultsFile: URL { outputDir.appendingPathComponent("results.tsv") }

    /// As the TS `prepareAlphaSkia`: Bravura (bundled with AlphaTabIOS) and the fonts the reference PNGs use.
    private static let prepared: Bool = {
        CoreGraphicsRenderer.enable()
        let fonts = [
            "font/noto-sans/NotoSans-Regular.otf",
            "font/noto-sans/NotoSans-Italic.otf",
            "font/noto-sans/NotoSans-Bold.otf",
            "font/noto-sans/NotoSans-BoldItalic.otf",
            "font/noto-serif/NotoSerif-Regular.otf",
            "font/noto-serif/NotoSerif-Italic.otf",
            "font/noto-serif/NotoSerif-Bold.otf",
            "font/noto-serif/NotoSerif-BoldItalic.otf",
            "font/noto-music/NotoMusic-Regular.otf",
            "font/noto-color-emoji/NotoColorEmoji_WindowsCompatible.ttf",
            "font/petaluma/Petaluma.otf"
        ]
        for font in fonts {
            CoreGraphicsRenderer.registerFont(TestPlatformPartials.resolve(font))
        }
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        // one test process writes one results file
        try? "group\tcase\tresult\tpercent\tdifferent/total\tnote\n".write(to: resultsFile, atomically: true, encoding: .utf8)
        return true
    }()

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["ALPHATAB_PNG_CHECK"] == "1" || strict
    }

    private static var strict: Bool {
        ProcessInfo.processInfo.environment["ALPHATAB_PNG_STRICT"] == "1"
    }

    /// Renders `options` with the Core Graphics engine and compares each run; returns the failures to raise.
    static func run(_ options: VisualTestOptions) async throws -> [String] {
        _ = prepared
        let settings = options.settings
        let engine = settings.core.engine
        settings.core.engine = CoreGraphicsRenderer.engine
        defer { settings.core.engine = engine }

        let rendered = try await VisualTestHelper.render(options)
        defer { try? rendered.api.destroy() }

        var failures: [String] = []
        for i in 0..<rendered.results.count {
            let run = options.runs[i]
            let image = try CoreGraphicsRenderer.compose(rendered.results[i], rendered.totalWidths[i], rendered.totalHeights[i], 1) { context in
                try options.prepareFullImage?(run, rendered.api, AlphaSkiaCanvas(context))
            }
            guard let image else {
                failures.append("Could not draw \(run.referenceFileName)")
                continue
            }
            let failure = compare(image, run.referenceFileName, options.tolerancePercent ?? 0)
            if let failure, strict {
                failures.append(failure)
            }
        }
        return failures
    }

    /// nil when `actual` matches the reference PNG within `tolerancePercent`, else why not. Records the case.
    static func compare(_ actual: CGImage, _ referenceFileName: String, _ tolerancePercent: Double) -> String? {
        let name = relativeName(referenceFileName)
        guard let source = CGImageSourceCreateWithURL(TestPlatformPartials.resolve(referenceFileName) as CFURL, nil),
              let expected = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            record(name, "missing", nil, "no reference PNG")
            write(actual, name + ".new.png")
            return "Missing reference image file \(referenceFileName)"
        }
        let width = expected.width
        let height = expected.height
        let sizeMismatch = actual.width != width || actual.height != height
        // as the TS: a different size is stretched onto the reference size, framed in red, and fails
        let actualPixels = pixels(actual, width, height, frame: sizeMismatch)
        let expectedPixels = pixels(expected, width, height, frame: false)

        let options = PixelMatchOptions()
        options.threshold = 0.3
        options.includeAA = false
        options.alpha = 1
        let match: PixelMatchResult
        do {
            match = try PixelMatch.match(Uint8Array(expectedPixels), Uint8Array(actualPixels), Double(width), Double(height), options)
        } catch {
            record(name, "error", nil, "\(error)")
            return "Error comparing images: \(error)"
        }
        // only pixels that are not transparent are relevant for the diff ratio
        let totalPixels = match.totalPixels - match.transparentPixels
        let percent = totalPixels > 0 ? match.differentPixels / totalPixels * 100 : 0
        let pass = percent <= tolerancePercent && !sizeMismatch
        let note = sizeMismatch ? "size \(actual.width)x\(actual.height), reference \(width)x\(height)" : ""
        record(name, pass ? "pass" : "fail", (percent, match.differentPixels, totalPixels), note)
        if pass {
            return nil
        }
        write(actual, name + ".new.png")
        writeDiff(expectedPixels, actualPixels, width, height, name + ".diff.png")
        var message = String(format: "Difference between original and new image is too big: %.0f/%.0f (%.2f%%)", match.differentPixels, totalPixels, percent)
        if sizeMismatch {
            message += " Image sizes do not match: expected \(width)x\(height) but got \(actual.width)x\(actual.height)"
        }
        return "\(referenceFileName): \(message)"
    }

    /// `test-data/visual-tests/general/song-details.png` -> `general/song-details`;
    /// `test-data/musicxml-testsuite/01a.png` -> `musicxml-testsuite/01a`
    static func relativeName(_ referenceFileName: String) -> String {
        var name = referenceFileName.replacingOccurrences(of: "\\", with: "/")
        for prefix in ["test-data/visual-tests/", "test-data/"] where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }
        return name.hasSuffix(".png") ? String(name.dropLast(4)) : name
    }

    private static func record(_ name: String, _ result: String, _ match: (Double, Double, Double)?, _ note: String) {
        let group = name.split(separator: "/").first.map(String.init) ?? name
        let numbers = match.map { String(format: "%.4f\t%.0f/%.0f", $0.0, $0.1, $0.2) } ?? "\t"
        let line = "\(group)\t\(name)\t\(result)\t\(numbers)\t\(note)\n"
        if let handle = try? FileHandle(forWritingTo: resultsFile) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        }
    }

    /// RGBA, premultiplied, rows top first: the layout alphaSkia's `readPixels` returns.
    static func pixels(_ image: CGImage, _ width: Int, _ height: Int, frame: Bool) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            if frame {
                context.setStrokeColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
                context.setLineWidth(2)
                context.stroke(CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        return data
    }

    private static func write(_ image: CGImage, _ relativePath: String) {
        let url = outputDir.appendingPathComponent(relativePath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// The reference faded, with every pixel that differs by more than a quarter of a channel in red. A picture for
    /// people only: PixelMatch decides the result.
    private static func writeDiff(_ expected: [UInt8], _ actual: [UInt8], _ width: Int, _ height: Int, _ relativePath: String) {
        var out = [UInt8](repeating: 255, count: width * height * 4)
        for i in stride(from: 0, to: out.count, by: 4) {
            var delta = 0
            for c in 0..<4 {
                delta = max(delta, abs(Int(expected[i + c]) - Int(actual[i + c])))
            }
            if delta > 64 {
                out[i] = 255
                out[i + 1] = 0
                out[i + 2] = 0
            } else {
                let gray = UInt8(255 - Int(expected[i + 3]) / 4)
                out[i] = gray
                out[i + 1] = gray
                out[i + 2] = gray
            }
        }
        let image = out.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        if let image {
            write(image, relativePath)
        }
    }
}
#endif
