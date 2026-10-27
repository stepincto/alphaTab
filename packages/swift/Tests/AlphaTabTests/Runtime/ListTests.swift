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

    @Test func fillReturnsTheSameList() {
        let l = List<Double>(1, 2).fill(0)
        #expect(l.join(",") == "0,0")
    }

    @Test func sortWithoutComparatorComparesStringsAsJs() {
        let l = List<Double>(10, 9, 1, 2).sort()
        #expect(l.join(",") == "1,10,2,9")
    }

    @Test func mathMaxMinOfASpreadList() {
        let l = List<Double>(3, 7, 5)
        #expect(Math.max(l) - Math.min(l) == 4)
        #expect(Math.max(List<Double>()) == -Double.infinity)
    }

    @Test func expectNotIsACallAsKotlin() {
        TestGlobals.expect(1.0).not().toBe(2.0)
    }

    @Test func expectToThrowOnAClosureThatReturnsAValue() {
        TestGlobals.expect({ () throws -> Double in throw JsError("x") }).toThrow()
    }

    @Test func filterNotNullDropsUndefined() {
        let l = List<Double?>(1, nil, 3)
        let out: List<Double> = l.filterNotNull()
        #expect(out.join(",") == "1,3")
    }

    @Test func concatReturnsNewListAndLeavesOriginals() {
        let a = List<String>("a", "b")
        let b = List<String>("c")
        let c = a.concat(b)
        #expect(c.join(",") == "a,b,c")
        #expect(a.length == 2)
        c.push("d")
        #expect(a.length == 2)
    }

    @Test func initFromIteratorDrainsIt() {
        let it: any IteratorProtocol<Double> = [65.0, 66.0].makeIterator()
        let l = List<Double>(it)
        #expect(l.join(",") == "65,66")
    }
}
