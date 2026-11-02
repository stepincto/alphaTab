// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#if canImport(CoreGraphics) && canImport(CoreText)
import AlphaTab
import AlphaTabRuntime
import CoreGraphics
import CoreText
import Foundation

/// alphaTab's `ICanvas` on Core Graphics and Core Text: the Apple counterpart of the C# `SkiaCanvas` and the
/// Kotlin `AndroidCanvas`. It follows `src/platform/skia/SkiaCanvas.ts` (and alphaSkia underneath it), because
/// alphaTab's reference images are drawn by alphaSkia: coordinates are multiplied by `display.scale`, the bitmap
/// is `highDpiFactor` pixels per point, and text is placed with alphaSkia's baselines.
public final class CoreGraphicsCanvas: ICanvas {
    private var _settings: Settings!
    public var settings: Settings {
        get { _settings }
        set { _settings = newValue }
    }

    public var color: Color = Color(0.0, 0.0, 0.0, 255.0)
    public var lineWidth: Double = 1.0
    public var font: Font = try! Font("Arial", 10.0)
    public var textAlign: TextAlign = TextAlign.Left
    public var textBaseline: TextBaseline = TextBaseline.Top

    private var context: CGContext?
    private var path = CGMutablePath()
    private var scale: Double = 1.0
    private var musicFamily: String = CoreGraphicsFonts.musicFontFamily
    private var fonts: [String: CTFont] = [:]

    public init() {}

    public func destroy() {
        context = nil
        fonts.removeAll()
    }

    public func onRenderFinished() -> Any? {
        return nil
    }

    public func beginRender(_ width: Double, _ height: Double) throws {
        scale = settings.display.scale
        musicFamily = PlatformBridge.smuflFontFamilyName(settings) ?? CoreGraphicsFonts.musicFontFamily
        let dpi = PlatformBridge.highDpiFactor
        // as alphaSkia: the surface is the whole points times the pixel factor
        let pixelWidth = max(1, Int(Double(Int(width)) * dpi))
        let pixelHeight = max(1, Int(Double(Int(height)) * dpi))
        context = CoreGraphicsCanvas.createContext(pixelWidth, pixelHeight)
        context?.scaleBy(x: dpi, y: dpi)
        path = CGMutablePath()
    }

    public func endRender() throws -> Any? {
        let image = context?.makeImage()
        context = nil
        return image
    }

    /// A transparent RGBA bitmap (premultiplied, sRGB, as alphaSkia's) with the origin top left, y down.
    public static func createContext(_ pixelWidth: Int, _ pixelHeight: Int) -> CGContext? {
        guard let context = CGContext(
            data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSubpixelPositioning(true)
        context.setShouldSubpixelPositionFonts(true)
        context.setAllowsFontSubpixelQuantization(false)
        context.setShouldSubpixelQuantizeFonts(false)
        context.setMiterLimit(4) // Skia's default
        return context
    }

    private var cgColor: CGColor {
        return CGColor(srgbRed: color.r / 255.0, green: color.g / 255.0, blue: color.b / 255.0, alpha: color.a / 255.0)
    }

    // MARK: rectangles and circles

    public func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        guard w > 0, let context else {
            return
        }
        context.setFillColor(cgColor)
        context.fill(CGRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale))
    }

    public func strokeRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        guard let context else {
            return
        }
        // as SkiaCanvas.ts: an odd line width is moved half a pixel so it covers whole pixels
        let blurOffset = lineWidth.truncatingRemainder(dividingBy: 2) == 0 ? 0.0 : 0.5
        context.setStrokeColor(cgColor)
        context.setLineWidth(lineWidth)
        context.stroke(CGRect(x: x * scale + blurOffset, y: y * scale + blurOffset, width: w * scale, height: h * scale))
    }

    public func fillCircle(_ x: Double, _ y: Double, _ radius: Double) {
        guard let context else {
            return
        }
        let r = radius * scale
        context.setFillColor(cgColor)
        context.fillEllipse(in: CGRect(x: x * scale - r, y: y * scale - r, width: 2 * r, height: 2 * r))
    }

    public func strokeCircle(_ x: Double, _ y: Double, _ radius: Double) {
        guard let context else {
            return
        }
        let r = radius * scale
        context.setStrokeColor(cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(x: x * scale - r, y: y * scale - r, width: 2 * r, height: 2 * r))
    }

    // MARK: paths

    public func beginPath() {
        path = CGMutablePath()
    }

    public func closePath() {
        if !path.isEmpty {
            path.closeSubpath()
        }
    }

    public func moveTo(_ x: Double, _ y: Double) {
        path.move(to: CGPoint(x: x * scale, y: y * scale))
    }

    public func lineTo(_ x: Double, _ y: Double) {
        ensureStarted(x, y)
        path.addLine(to: CGPoint(x: x * scale, y: y * scale))
    }

    public func quadraticCurveTo(_ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) {
        ensureStarted(cpx, cpy)
        path.addQuadCurve(to: CGPoint(x: x * scale, y: y * scale), control: CGPoint(x: cpx * scale, y: cpy * scale))
    }

    public func bezierCurveTo(_ cp1X: Double, _ cp1Y: Double, _ cp2X: Double, _ cp2Y: Double, _ x: Double, _ y: Double) {
        ensureStarted(cp1X, cp1Y)
        path.addCurve(
            to: CGPoint(x: x * scale, y: y * scale),
            control1: CGPoint(x: cp1X * scale, y: cp1Y * scale),
            control2: CGPoint(x: cp2X * scale, y: cp2Y * scale)
        )
    }

    /// A canvas path segment without a current point starts at its first point (CG would trap instead).
    private func ensureStarted(_ x: Double, _ y: Double) {
        if path.isEmpty {
            path.move(to: CGPoint(x: x * scale, y: y * scale))
        }
    }

    public func fill() {
        guard let context, !path.isEmpty else {
            return
        }
        context.setFillColor(cgColor)
        context.addPath(path)
        context.fillPath(using: .winding)
    }

    public func stroke() {
        guard let context, !path.isEmpty else {
            return
        }
        context.setStrokeColor(cgColor)
        context.setLineWidth(lineWidth)
        context.addPath(path)
        context.strokePath()
    }

    // MARK: groups and rotation

    public func beginGroup(_ identifier: String) {
        // not supported, as in SkiaCanvas: a bitmap has no groups
    }

    public func endGroup() {
    }

    public func beginRotate(_ centerX: Double, _ centerY: Double, _ angle: Double) {
        context?.saveGState()
        context?.translateBy(x: centerX * scale, y: centerY * scale)
        context?.rotate(by: angle * Double.pi / 180.0)
    }

    public func endRotate() {
        context?.restoreGState()
    }

    // MARK: text

    public func fillText(_ text: String, _ x: Double, _ y: Double) throws {
        if text.isEmpty {
            return
        }
        let size = font.size * scale
        let ctFont = textFont(size)
        drawText(text, ctFont, size, x * scale, y * scale, textAlign, textBaseline)
    }

    public func measureText(_ text: String) throws -> MeasuredText {
        if text.isEmpty {
            return MeasuredText(0, 0)
        }
        // as SkiaCanvas.ts: measured at the unscaled size
        let line = CoreGraphicsFonts.line(text, textFont(font.size))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        // alphaSkia rounds the advance to 1/100 (SkParagraph's littleRound) and the ink box out to whole pixels, each side at least 0
        let height = bounds.isNull ? 0 : max(0, bounds.maxY.rounded(.up)) + max(0, (-bounds.minY).rounded(.up))
        return MeasuredText(CoreGraphicsFonts.advance(line), height)
    }

    public func fillMusicFontSymbol(_ x: Double, _ y: Double, _ relativeScale: Double, _ symbol: MusicFontSymbol, _ centerAtPosition: Bool?) throws {
        if symbol == MusicFontSymbol.None {
            return
        }
        fillMusicFontSymbolText(x, y, relativeScale, CoreGraphicsFonts.symbolText([symbol]), centerAtPosition)
    }

    public func fillMusicFontSymbols(_ x: Double, _ y: Double, _ relativeScale: Double, _ symbols: List<MusicFontSymbol>, _ centerAtPosition: Bool?) throws {
        let text = CoreGraphicsFonts.symbolText(symbols.filter { $0 != MusicFontSymbol.None })
        fillMusicFontSymbolText(x, y, relativeScale, text, centerAtPosition)
    }

    private func fillMusicFontSymbolText(_ x: Double, _ y: Double, _ relativeScale: Double, _ text: String, _ centerAtPosition: Bool?) {
        if text.isEmpty {
            return
        }
        let size = settings.display.resources.engravingSettings.musicFontSize * scale * relativeScale
        let ctFont = cachedFont([musicFamily], false, false, size)
        drawText(text, ctFont, size, x * scale, y * scale, centerAtPosition == true ? .Center : .Left, .Alphabetic)
    }

    private func textFont(_ size: Double) -> CTFont {
        return cachedFont(Swift.Array(font.families), font.isBold, font.isItalic, size)
    }

    private func cachedFont(_ families: [String], _ bold: Bool, _ italic: Bool, _ size: Double) -> CTFont {
        let key = "\(families.joined(separator: ","))|\(bold)|\(italic)|\(size)"
        if let font = fonts[key] {
            return font
        }
        let font = CoreGraphicsFonts.resolve(families, bold, italic, size)
        fonts[key] = font
        return font
    }

    /// Draws `text` with its alignment point at (`x`, `y`) in device-independent pixels (already scaled).
    private func drawText(_ text: String, _ ctFont: CTFont, _ size: Double, _ x: Double, _ y: Double, _ align: TextAlign, _ baseline: TextBaseline) {
        guard let context else {
            return
        }
        let line = CoreGraphicsFonts.line(text, ctFont)
        var originX = x
        switch align {
        case .Left:
            break
        case .Center:
            originX -= CoreGraphicsFonts.advance(line) / 2
        case .Right:
            originX -= CoreGraphicsFonts.advance(line)
        }
        // Skia places horizontal text on whole device pixels vertically (subpixel positioning is along x only)
        let dpi = PlatformBridge.highDpiFactor
        let originY = ((y + CoreGraphicsFonts.baselineOffset(ctFont, size, baseline)) * dpi).rounded() / dpi
        context.saveGState()
        context.setFillColor(cgColor)
        // the context is flipped (y down); flip the glyphs back
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: originX, y: originY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

/// Font lookup, text lines and alphaSkia's text metrics for `CoreGraphicsCanvas`.
public enum CoreGraphicsFonts {
    /// The SMuFL font alphaTab draws music symbols with, bundled with this package.
    public static let musicFontFamily = "Bravura"

    /// Generic CSS families alphaTab's default fonts end with, mapped to fonts every Apple platform has.
    private static let genericFamilies: [String: String] = [
        "sans-serif": "Helvetica", "serif": "Times New Roman", "monospace": "Courier", "cursive": "Snell Roundhand"
    ]

    /// The first of `families` that is installed, the others as its fallback (cascade) list; the system font when
    /// none is.
    public static func resolve(_ families: [String], _ bold: Bool, _ italic: Bool, _ size: Double) -> CTFont {
        var traits: UInt32 = 0
        if bold {
            traits |= CTFontSymbolicTraits.traitBold.rawValue
        }
        if italic {
            traits |= CTFontSymbolicTraits.traitItalic.rawValue
        }
        var matches: [CTFontDescriptor] = []
        for family in families {
            let name = genericFamilies[family.lowercased()] ?? family
            let attributes: [CFString: Any] = [
                kCTFontFamilyNameAttribute: name,
                kCTFontTraitsAttribute: [kCTFontSymbolicTrait: traits]
            ]
            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
            let mandatory = NSSet(object: kCTFontFamilyNameAttribute) as CFSet
            if let match = CTFontDescriptorCreateMatchingFontDescriptor(descriptor, mandatory) {
                matches.append(match)
            }
        }
        guard let primary = matches.first else {
            let system = CTFontCreateUIFontForLanguage(.system, size, nil)!
            return CTFontCreateCopyWithSymbolicTraits(system, size, nil, CTFontSymbolicTraits(rawValue: traits), CTFontSymbolicTraits(rawValue: traits)) ?? system
        }
        let base = CTFontCreateWithFontDescriptor(primary, size, nil)
        if matches.count == 1 {
            return base
        }
        let cascade = CTFontDescriptorCreateWithAttributes([kCTFontCascadeListAttribute: Swift.Array(matches.dropFirst())] as CFDictionary)
        return CTFontCreateCopyWithAttributes(base, size, nil, cascade)
    }

    /// One line of `text` in `font`, drawn with the context's fill colour.
    public static func line(_ text: String, _ font: CTFont) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// The advance of a line, rounded to 1/100 as alphaSkia (SkParagraph's `littleRound`) reports it.
    public static func advance(_ line: CTLine) -> Double {
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        return (width * 100).rounded() / 100
    }

    /// How far below a `baseline` alignment line the alphabetic baseline lies, for text of `size` pixels.
    /// alphaSkia (SkParagraph) rounds the font's ascent and descent to whole pixels; `Top` is its hanging
    /// baseline (80% of the ascent), `Middle` and `Bottom` use the em box split in the ratio of ascent to descent.
    public static func baselineOffset(_ font: CTFont, _ size: Double, _ baseline: TextBaseline) -> Double {
        let ascent = Double(CTFontGetAscent(font))
        let descent = Double(CTFontGetDescent(font))
        switch baseline {
        case .Alphabetic:
            return 0
        case .Top:
            return ascent.rounded() * 0.8
        case .Middle:
            return emAscent(size, ascent, descent) - size / 2
        case .Bottom:
            return -(size - emAscent(size, ascent, descent))
        }
    }

    private static func emAscent(_ size: Double, _ ascent: Double, _ descent: Double) -> Double {
        let total = ascent + descent
        return total > 0 ? (size * ascent / total).rounded() : size
    }

    /// The text of SMuFL symbols: each symbol's value is its code point.
    static func symbolText<S: Sequence>(_ symbols: S) -> String where S.Element == MusicFontSymbol {
        var text = ""
        for symbol in symbols {
            if let scalar = Unicode.Scalar(UInt32(symbol.rawValue)) {
                text.unicodeScalars.append(scalar)
            }
        }
        return text
    }
}
#endif
