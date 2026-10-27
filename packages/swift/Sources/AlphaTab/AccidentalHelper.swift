// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: src/rendering/utils/AccidentalHelper.ts is a renderer class (it holds a LineBarRenderer and
// casts to ScoreBarRenderer), so it stays out of the transpile filter. MusicXmlImporter and the NoteSteps
// tests name only its pure static `calculateNoteSteps`; this stand-in is that function, ported line by
// line. Delete it when the renderer tier generates AccidentalHelper.

/// Stand-in for `AccidentalHelper` (src/rendering/utils/AccidentalHelper.ts).
internal final class AccidentalHelper {
    private static let _stepsPerOctave: Double = 7.0

    private static let _octaveSteps: [Double] = [38.0, 32.0, 30.0, 26.0, 38.0]

    private static let _diatonicSteps: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

    static func calculateNoteSteps(_ clef: Clef, _ spelling: ResolvedSpelling) -> Double {
        let clefValue = Int(clef.rawValue)
        // Initial Position
        var steps: Double = AccidentalHelper._octaveSteps[clefValue]
        // Move to Octave
        steps -= spelling.octave * AccidentalHelper._stepsPerOctave
        // Move within octave
        steps -= AccidentalHelper._diatonicSteps[Int(spelling.degree)]
        return steps
    }
}
