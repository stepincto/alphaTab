// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `Math.max(...set)` / `Math.min(...set)` (ECMA-262 21.3.2.24/25).
@Suite struct MathTests {
    @Test func maxMinOfSet() {
        let s = AlphaTabRuntime.Set<Double>([3, 1, 2])
        #expect(Math.max(s) == 3)
        #expect(Math.min(s) == 1)
    }

    @Test func emptySetIsInfinity() {
        let s = AlphaTabRuntime.Set<Double>()
        #expect(Math.max(s) == -Double.infinity)
        #expect(Math.min(s) == Double.infinity)
    }

    @Test func nanInSetWins() {
        let s = AlphaTabRuntime.Set<Double>([1, Double.nan, 5])
        #expect(Math.max(s).isNaN)
        #expect(Math.min(s).isNaN)
    }
}
