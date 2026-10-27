// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.


import AlphaTabRuntime
import Testing

/// JS `Array` (ECMA-262 23.1).
@Suite struct ListTests {
    @Test func findReturnsFirstMatchOrNil() {
        let l = List<Double>(1, 2, 3, 4)
        #expect(l.find { $0 > 2 } == 3)
        #expect(l.find { $0 > 9 } == nil)
    }

    @Test func lengthConstructorThenFill() {
        let l = List<String>(3)
        #expect(l.length == 3)
        l.fill("")
        l[1] = "a"
        #expect(l.join(",") == ",a,")
    }

    @Test func singleDoubleIsAnElementNotALength() {
        let l = List<Double>(60.0)
        #expect(l.length == 1)
        #expect(l[0] == 60)
    }
}
