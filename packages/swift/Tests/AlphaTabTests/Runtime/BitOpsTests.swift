// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS bit operators work on ToInt32 / ToUint32 values (ECMA-262 7.1.6, 7.1.7).
@Suite struct BitOpsTests {
    @Test func shiftLeftWrapsToInt32() {
        #expect(jsShl(1, 31) == -2_147_483_648)
        #expect(jsShl(1, 32) == 1)
        #expect(jsShl(1, 33) == 2)
    }

    @Test func unsignedShiftGivesUint32() {
        #expect(jsUshr(-1, 0) == 4_294_967_295)
        #expect(jsUshr(-1, 28) == 15)
        #expect(jsUshr(8, 33) == 4)
    }

    @Test func signedShiftKeepsSign() {
        #expect(jsShr(-16, 2) == -4)
        #expect(jsShr(-1, 31) == -1)
        #expect(jsShr(16, 34) == 4)
        #expect(jsShr(2_147_483_648, 0) == -2_147_483_648)
    }

    @Test func orZeroTruncatesTowardZeroToInt32() {
        #expect(jsOr(4_294_967_295, 0) == -1)
        #expect(jsOr(3.7, 0) == 3)
        #expect(jsOr(-3.7, 0) == -3)
        #expect(jsOr(Double.nan, 0) == 0)
        #expect(jsOr(Double.infinity, 0) == 0)
        #expect(jsOr(-Double.infinity, 0) == 0)
        #expect(jsOr(1_099_511_627_776, 0) == 0) // 2^40
        #expect(jsOr(1_099_511_627_777, 0) == 1)
        #expect(jsOr(-2_147_483_649, 0) == 2_147_483_647)
    }

    @Test func andXorNot() {
        #expect(jsAnd(0x1ff, 0xff) == 255)
        #expect(jsAnd(-1, 4_294_967_295) == -1)
        #expect(jsXor(0xff, 0x0f) == 0xf0)
        #expect(jsXor(2_147_483_647, -1) == -2_147_483_648)
        #expect(jsNot(0) == -1)
        #expect(jsNot(-1) == 0)
        #expect(jsNot(2_147_483_647) == -2_147_483_648)
        #expect(jsNot(Double.nan) == -1)
    }
}
