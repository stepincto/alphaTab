// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `x++`, `++x`, `x--`, `--x` used as values (ECMA-262 13.4).
@Suite struct IncrementTests {
    @Test func postfixGivesTheOldValuePrefixTheNewOne() {
        var x = 1.0
        #expect(jsPostInc(&x) == 1)
        #expect(x == 2)
        #expect(jsPreInc(&x) == 3)
        #expect(jsPostDec(&x) == 3)
        #expect(x == 2)
        #expect(jsPreDec(&x) == 1)
        #expect(x == 1)
    }
}
