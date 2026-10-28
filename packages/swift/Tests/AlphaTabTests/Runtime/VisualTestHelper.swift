// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime

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

final class VisualTestOptions {
    var score: Score
    var runs: List<VisualTestRun>
    var settings: Settings
    var tracks: List<Double>?
    var tolerancePercent: Double?

    init(_ score: Score, _ runs: List<VisualTestRun>, _ settings: Settings?) {
        self.score = score
        self.runs = runs
        self.settings = settings ?? Settings()
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

    static func runVisualTestFull(_ options: VisualTestOptions) async throws {
        throw JsError("SVG golden comparison is not implemented yet")
    }
}
