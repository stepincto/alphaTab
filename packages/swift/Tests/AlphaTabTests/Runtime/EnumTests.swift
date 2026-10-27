// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.


import AlphaTabRuntime
import Testing

/// Order declared out of value order, so a declaration-order comparison would fail.
private enum TestDuration: Int, IAlphaTabEnum, CaseIterable {
    case Half = 2
    case QuadrupleWhole = -4
    case Whole = 1
}

/// JS enums are numbers: `<`, `>`, `<=`, `>=` compare the values.
@Suite struct EnumTests {
    @Test func relationalOperatorsCompareValues() {
        #expect(TestDuration.QuadrupleWhole < TestDuration.Whole)
        #expect(TestDuration.Half > TestDuration.Whole)
        #expect(TestDuration.Whole <= TestDuration.Whole)
        #expect(TestDuration.Half >= TestDuration.QuadrupleWhole)
        #expect(!(TestDuration.Whole > TestDuration.Half))
        #expect([TestDuration.Half, .QuadrupleWhole, .Whole].max() == .Half)
    }
}
