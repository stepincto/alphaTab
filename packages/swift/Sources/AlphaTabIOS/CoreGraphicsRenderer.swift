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

/// Registers the Core Graphics render engine and renders scores to images.
public enum CoreGraphicsRenderer {
    /// The `settings.core.engine` name of `CoreGraphicsCanvas`.
    public static let engine = "coregraphics"

    private static let registered: Bool = {
        // the bundled Bravura, for the process only; a second registration of the same file fails harmlessly
        if let url = Bundle.module.url(forResource: "Bravura", withExtension: "otf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        Environment.renderEngines.set(engine, RenderEngineFactory(true, { () -> any ICanvas in CoreGraphicsCanvas() }))
        return true
    }()

    /// Registers Bravura with Core Text and the `coregraphics` engine with `Environment`, as `Environment`
    /// registers `svg`. Safe to call more than once.
    public static func enable() {
        _ = registered
    }

    /// Registers a font file (OTF/TTF) with Core Text for this process, so `Font` families can name it.
    @discardableResult
    public static func registerFont(_ url: URL) -> Bool {
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// A rendered score: the image (`scale` pixels per point) and where each beat and bar landed, in points.
    public struct Result {
        public let image: CGImage
        public let width: Double
        public let height: Double
        public let boundsLookup: BoundsLookup?
    }

    /// Lays out and draws `score` at `width` points into one image of `scale` pixels per point.
    /// `settings.core.engine` and `enableLazyLoading` are overwritten; `PlatformBridge.highDpiFactor` (a process
    /// global, as in alphaTab) is set to `scale`.
    public static func render(_ score: Score, width: Double, scale: Double = 1, tracks: [Int] = [0], settings: Settings = Settings()) throws -> Result {
        enable()
        settings.core.engine = engine
        settings.core.enableLazyLoading = false
        PlatformBridge.highDpiFactor = scale

        let renderer = try ScoreRenderer(settings)
        defer { renderer.destroy() }
        renderer.width = width
        var partials: [RenderFinishedEventArgs] = []
        var total: RenderFinishedEventArgs?
        var failure: JsError?
        renderer.partialRenderFinished.on { partials.append($0) }
        renderer.renderFinished.on { total = $0 }
        renderer.error.on { failure = $0 }
        try renderer.renderScore(score, List<Double>(contentsOf: tracks.map { Double($0) }))
        if let failure {
            throw failure
        }
        guard let total else {
            throw JsError("alphaTab finished without a render result (width \(width))")
        }
        guard let image = compose(partials, total.totalWidth, total.totalHeight, scale) else {
            throw JsError("could not create a \(total.totalWidth)x\(total.totalHeight) bitmap at scale \(scale)")
        }
        return Result(image: image, width: total.totalWidth, height: total.totalHeight, boundsLookup: renderer.boundsLookup)
    }

    /// Imports alphaTex or any file alphaTab reads (Guitar Pro, MusicXML, capella) and renders it.
    public static func render(data: Data, width: Double, scale: Double = 1, tracks: [Int] = [0], settings: Settings = Settings()) throws -> Result {
        let score = try ScoreLoader.loadScoreFromBytes(Uint8Array([UInt8](data)), settings)
        return try render(score, width: width, scale: scale, tracks: tracks, settings: settings)
    }

    /// Draws each partial image at its place in one bitmap of the total size, then `overlay` (in points) on top.
    public static func compose(_ partials: [RenderFinishedEventArgs], _ totalWidth: Double, _ totalHeight: Double, _ scale: Double, overlay: ((CGContext) throws -> Void)? = nil) rethrows -> CGImage? {
        guard let context = CoreGraphicsCanvas.createContext(
            max(1, Int(Double(Int(totalWidth)) * scale)), max(1, Int(Double(Int(totalHeight)) * scale))
        ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        for partial in partials {
            guard let result = partial.renderResult, CFGetTypeID(result as CFTypeRef) == CGImage.typeID else {
                continue
            }
            let image = result as! CGImage
            // as the TS visual tests (alphaSkia drawImage): stretched onto the partial's own, possibly fractional, rect
            draw(image, in: context, CGRect(x: partial.x, y: partial.y, width: partial.width, height: partial.height))
        }
        try overlay?(context)
        return context.makeImage()
    }

    /// Draws `image` upright into a top-left-origin context.
    public static func draw(_ image: CGImage, in context: CGContext, _ rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}
#endif
