// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import AlphaTabRuntime
import Testing

private final class Box {}

/// `TypeHelper.strictEquals` is JS `===` on two `unknown` values.
@Suite struct TypeHelperTests {
    @Test func strictEqualsPrimitivesByValue() {
        #expect(TypeHelper.strictEquals(nil, nil))
        #expect(!TypeHelper.strictEquals(nil, 0.0))
        #expect(TypeHelper.strictEquals(1.5, 1.5))
        #expect(TypeHelper.strictEquals(2, 2.0))
        #expect(!TypeHelper.strictEquals(Double.nan, Double.nan))
        #expect(TypeHelper.strictEquals("a", "a"))
        #expect(!TypeHelper.strictEquals("1", 1.0))
        #expect(TypeHelper.strictEquals(true, true))
        #expect(!TypeHelper.strictEquals(true, 1.0))
    }

    @Test func strictEqualsObjectsByReference() {
        let a = Box()
        #expect(TypeHelper.strictEquals(a, a))
        #expect(!TypeHelper.strictEquals(a, Box()))
        let optional: Any? = Optional<Box>.none
        #expect(TypeHelper.strictEquals(optional, nil))
    }
}
