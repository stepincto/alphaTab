// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// TS `x!` and `x as T` lowered to throwing helpers: a failure is a catchable `JsError`, not a trap.
@Suite struct AssertionTests {
    private class Base {}
    private final class Derived: Base {}
    private final class Other: Base {}

    @Test func nonNullReturnsTheValue() throws {
        let x: Double? = 3
        #expect(try jsNonNull(x) == 3)
    }

    @Test func nonNullThrowsOnNil() {
        let x: String? = nil
        #expect(throws: JsError.self) { try jsNonNull(x) }
    }

    @Test func castReturnsTheValue() throws {
        let b: Base = Derived()
        #expect(try jsCast(b, Derived.self) === b)
    }

    @Test func castThrowsOnWrongTypeOrNil() {
        let b: Base = Other()
        let n: Base? = nil
        #expect(throws: JsError.self) { try jsCast(b, Derived.self) }
        #expect(throws: JsError.self) { try jsCast(n, Derived.self) }
    }
}

/// `xs[i].m` in a throwing function: out of range throws, as Kotlin's IndexOutOfBoundsException.
@Suite struct ListElementTests {
    @Test func jsElementReadsInRange() throws {
        #expect(try List<Double>(1.0, 2.0).jsElement(1) == 2)
    }

    @Test func jsElementThrowsOutOfRange() {
        let xs = List<Double>(1.0)
        #expect(throws: JsError.self) { try xs.jsElement(1) }
        #expect(throws: JsError.self) { try xs.jsElement(-1) }
    }
}
